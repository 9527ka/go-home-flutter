import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../utils/content_filter.dart';
import '../utils/storage.dart';

/// WebSocket 连接状态
enum WsConnectionState {
  disconnected, // 未连接
  connecting,   // 连接中
  connected,    // 已连接（未认证）
  authenticated, // 已连接且认证
  reconnecting, // 重连中
}

class ChatProvider extends ChangeNotifier with WidgetsBindingObserver {
  final ChatService _chatService = ChatService();

  // ===== 消息状态 =====
  List<ChatMessageModel> _messages = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _onlineCount = 0;

  // ===== 消息去重 =====
  final Set<int> _messageIds = {};

  // ===== 待发送队列（断线重连后自动重发） =====
  final List<String> _pendingMessages = [];

  // ===== WebSocket 状态 =====
  WsConnectionState _connectionState = WsConnectionState.disconnected;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  // ===== 心跳 & 重连 =====
  Timer? _pingTimer;
  Timer? _pongTimeoutTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _manualDisconnect = false; // 用户主动断开，不自动重连
  DateTime? _lastPongTime;

  // ===== 页面引用计数（控制 WS 生命周期） =====
  int _pageRefCount = 0;

  // ===== 未读消息红点 =====
  bool _hasUnread = false;

  // ===== 外部消息 handler 注册（供 FriendProvider / ConversationProvider 订阅） =====
  final Map<String, List<void Function(Map<String, dynamic>)>> _externalHandlers = {};

  /// 注册外部消息处理器（如 friend_request, private_message 等）
  void registerHandler(String type, void Function(Map<String, dynamic>) handler) {
    _externalHandlers.putIfAbsent(type, () => []).add(handler);
  }

  /// 移除外部消息处理器
  void removeHandler(String type, void Function(Map<String, dynamic>) handler) {
    _externalHandlers[type]?.remove(handler);
  }

  // ===== 配置常量 =====
  static const int _pingIntervalSec = 25;
  static const int _pongTimeoutSec = 10;
  static const int _maxReconnectAttempts = 20;
  static const int _baseReconnectDelaySec = 2;
  static const int _maxReconnectDelaySec = 60;
  static const int _authTimeoutSec = 10;
  static const int _maxMessageCacheSize = 500; // 内存中最多保留消息数

  // ===== Getters =====
  List<ChatMessageModel> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  int get onlineCount => _onlineCount;
  WsConnectionState get connectionState => _connectionState;
  bool get isConnected =>
      _connectionState == WsConnectionState.connected ||
      _connectionState == WsConnectionState.authenticated;
  bool get isAuthenticated =>
      _connectionState == WsConnectionState.authenticated;
  int get reconnectAttempts => _reconnectAttempts;
  int get pendingCount => _pendingMessages.length;
  bool get hasUnread => _hasUnread;

  // ===== 初始化 & 销毁 =====

  ChatProvider() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _manualDisconnect = true;
    _cleanup();
    super.dispose();
  }

  // ===== 页面生命周期管理 =====

  /// ChatPage 进入时调用，开始连接
  void onPageEnter() {
    _pageRefCount++;
    // 进入聊天页面，清除未读红点
    if (_hasUnread) {
      _hasUnread = false;
      notifyListeners();
    }
    // 加载屏蔽用户列表
    loadBlockedUsers();
    if (_pageRefCount == 1) {
      debugPrint('[WS] Page entered, connecting...');
      connect();
    }
  }

  /// ChatPage 退出时调用，断开连接（节省资源）
  void onPageLeave() {
    _pageRefCount--;
    if (_pageRefCount <= 0) {
      _pageRefCount = 0;
      debugPrint('[WS] Page left, disconnecting...');
      _manualDisconnect = true;
      _cleanup();
      _setConnectionState(WsConnectionState.disconnected);
      _onlineCount = 0;
      // 不清除消息，下次进入聊天室还能看到

      // 保存最后已读消息 ID（用于下次检测未读）
      _saveLastReadId();
    }
  }

  /// 检查是否有未读消息（首页调用，轻量 API 请求）
  Future<void> checkUnread() async {
    try {
      final data = await _chatService.getHistory(limit: 1);
      final list = data['list'] as List?;
      if (list == null || list.isEmpty) return;

      final latestId = list.last['id'] as int? ?? 0;
      if (latestId <= 0) return;

      final lastReadId = await StorageUtil.getLastReadChatId();
      final unread = latestId > lastReadId;

      if (unread != _hasUnread) {
        _hasUnread = unread;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[Chat] checkUnread error: $e');
    }
  }

  /// 保存当前最后一条消息的 ID 为已读
  Future<void> _saveLastReadId() async {
    if (_messages.isNotEmpty) {
      // 从后往前找最新的有 id 的消息
      for (var i = _messages.length - 1; i >= 0; i--) {
        final id = _messages[i].id;
        if (id != null && id > 0) {
          await StorageUtil.saveLastReadChatId(id);
          break;
        }
      }
    }
  }

  /// 监听 App 前后台切换
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 只在聊天页面打开时才处理
    if (_pageRefCount <= 0) return;

    switch (state) {
      case AppLifecycleState.resumed:
        // 从后台回到前台，检查连接
        if (!_manualDisconnect && _connectionState == WsConnectionState.disconnected) {
          debugPrint('[WS] App resumed, reconnecting...');
          _reconnectAttempts = 0; // 前台回来重置重连计数
          connect();
        } else if (isConnected) {
          // 已连接时恢复心跳
          _startHeartbeat();
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // 进入后台，保持连接但停止心跳（省电）
        _pingTimer?.cancel();
        _pongTimeoutTimer?.cancel();
        break;
      default:
        break;
    }
  }

  // ===== 历史消息 =====

  /// 加载历史消息
  Future<void> loadHistory() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      final data = await _chatService.getHistory(limit: 50);
      final list = (data['list'] as List?)
              ?.map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];

      _messages = list;
      _messageIds.clear();
      for (final msg in list) {
        if (msg.id != null) _messageIds.add(msg.id!);
      }
      _hasMore = data['has_more'] == true;

      // 加载完成后，标记最新消息为已读
      _saveLastReadId();
    } catch (e) {
      debugPrint('[WS] loadHistory error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 加载更早的消息
  Future<void> loadMore() async {
    if (_isLoading || !_hasMore || _messages.isEmpty) return;
    _isLoading = true;
    notifyListeners();

    try {
      final firstId = _messages.first.id;
      if (firstId == null) return;

      final data = await _chatService.getHistory(beforeId: firstId, limit: 50);
      final list = (data['list'] as List?)
              ?.map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];

      // 去重后插入
      final newMessages = list.where((msg) {
        if (msg.id == null) return true;
        return !_messageIds.contains(msg.id);
      }).toList();

      for (final msg in newMessages) {
        if (msg.id != null) _messageIds.add(msg.id!);
      }
      _messages.insertAll(0, newMessages);
      _hasMore = data['has_more'] == true;
    } catch (e) {
      debugPrint('[WS] loadMore error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ===== WebSocket 连接 =====

  /// 连接 WebSocket
  Future<void> connect() async {
    // 防止重复连接
    if (_connectionState == WsConnectionState.connecting ||
        _connectionState == WsConnectionState.connected ||
        _connectionState == WsConnectionState.authenticated) {
      debugPrint('[WS] Already connected/connecting, skip');
      return;
    }

    _manualDisconnect = false;
    _setConnectionState(WsConnectionState.connecting);
    debugPrint('[WS] Connecting to ${ApiConfig.wsUrl} (attempt #$_reconnectAttempts)...');

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(ApiConfig.wsUrl),
      );

      // 等待连接就绪
      await _channel!.ready;

      _setConnectionState(WsConnectionState.connected);
      _reconnectAttempts = 0; // 连接成功，重置重连计数
      _lastPongTime = DateTime.now();
      debugPrint('[WS] Connected successfully');

      // 监听消息流
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: (error) {
          debugPrint('[WS] Stream error: $error');
          _onDisconnected();
        },
        onDone: () {
          debugPrint('[WS] Stream done (closeCode=${_channel?.closeCode}, reason=${_channel?.closeReason})');
          _onDisconnected();
        },
        cancelOnError: false,
      );

      // 发送认证
      await _authenticate();

      // 启动心跳
      _startHeartbeat();

    } catch (e) {
      debugPrint('[WS] Connect error: $e');
      _setConnectionState(WsConnectionState.disconnected);
      _scheduleReconnect();
    }
  }

  /// 主动断开连接
  void disconnect() {
    debugPrint('[WS] Manual disconnect');
    _manualDisconnect = true;
    _cleanup();
    _setConnectionState(WsConnectionState.disconnected);
  }

  /// 手动触发重连（UI 上的"重连"按钮）
  void manualReconnect() {
    debugPrint('[WS] Manual reconnect requested');
    _cleanup();
    _reconnectAttempts = 0;
    _manualDisconnect = false;
    connect();
  }

  // ===== 屏蔽用户列表 =====
  final Set<int> _blockedUserIds = {};

  Set<int> get blockedUserIds => _blockedUserIds;

  /// 初始化屏蔽列表（从本地存储加载）
  Future<void> loadBlockedUsers() async {
    final list = await StorageUtil.getBlockedUsers();
    _blockedUserIds.clear();
    _blockedUserIds.addAll(list);
  }

  /// 屏蔽用户
  Future<void> blockUser(int userId) async {
    _blockedUserIds.add(userId);
    await StorageUtil.addBlockedUser(userId);
    // 上报服务端
    try {
      await _chatService.reportUser(userId, reason: 'blocked_by_user');
    } catch (_) {}
    notifyListeners();
  }

  /// 取消屏蔽
  Future<void> unblockUser(int userId) async {
    _blockedUserIds.remove(userId);
    await StorageUtil.removeBlockedUser(userId);
    notifyListeners();
  }

  /// 检查用户是否被屏蔽
  bool isUserBlocked(int userId) => _blockedUserIds.contains(userId);

  /// 发送文本消息（带敏感词过滤）
  void sendMessage(String content) {
    final text = content.trim();
    if (text.isEmpty) return;

    // 客户端敏感词过滤
    final filtered = ContentFilter.filter(text);

    if (!isAuthenticated) {
      if (isConnected || _connectionState == WsConnectionState.reconnecting) {
        _pendingMessages.add(filtered);
        debugPrint('[WS] Message queued (pending: ${_pendingMessages.length})');
      } else {
        debugPrint('[WS] Not connected, cannot send');
      }
      return;
    }

    _send({'type': 'message', 'content': filtered});
  }

  /// 发送多媒体消息（图片/视频/语音）
  void sendMediaMessage({
    required String msgType,
    required String mediaUrl,
    String thumbUrl = '',
    String content = '',
    Map<String, dynamic>? mediaInfo,
  }) {
    if (!isAuthenticated) {
      debugPrint('[WS] Not authenticated, cannot send media');
      return;
    }

    final data = <String, dynamic>{
      'type': 'message',
      'msg_type': msgType,
      'content': content,
      'media_url': mediaUrl,
      'thumb_url': thumbUrl,
    };
    if (mediaInfo != null) {
      data['media_info'] = mediaInfo;
    }
    _send(data);
  }

  // ===== 内部方法 =====

  void _setConnectionState(WsConnectionState state) {
    if (_connectionState == state) return;
    _connectionState = state;
    notifyListeners();
  }

  /// 认证
  Future<void> _authenticate() async {
    final token = await StorageUtil.getToken();
    if (token == null || token.isEmpty) {
      debugPrint('[WS] No token, skip auth');
      return;
    }

    _send({'type': 'auth', 'token': token});

    // 认证超时检测：如果 N 秒内没收到 auth_success，不影响浏览
    Timer(Duration(seconds: _authTimeoutSec), () {
      if (_connectionState == WsConnectionState.connected) {
        debugPrint('[WS] Auth timeout, staying as connected (read-only)');
      }
    });
  }

  /// 启动心跳
  void _startHeartbeat() {
    _pingTimer?.cancel();
    _pongTimeoutTimer?.cancel();

    _pingTimer = Timer.periodic(
      const Duration(seconds: _pingIntervalSec),
      (_) {
        if (!isConnected) return;

        _send({'type': 'ping'});

        // 启动 pong 超时检测
        _pongTimeoutTimer?.cancel();
        _pongTimeoutTimer = Timer(
          const Duration(seconds: _pongTimeoutSec),
          () {
            debugPrint('[WS] Pong timeout! Last pong: $_lastPongTime');
            // Pong 超时，认为连接已断开
            _onDisconnected();
          },
        );
      },
    );
  }

  /// 发送待发送队列中的消息
  void _flushPendingMessages() {
    if (_pendingMessages.isEmpty || !isAuthenticated) return;

    debugPrint('[WS] Flushing ${_pendingMessages.length} pending messages');
    final pending = List<String>.from(_pendingMessages);
    _pendingMessages.clear();

    for (final text in pending) {
      _send({'type': 'message', 'content': text});
    }
  }

  /// 连接断开处理
  void _onDisconnected() {
    _cleanup();
    _setConnectionState(WsConnectionState.disconnected);

    if (!_manualDisconnect) {
      _scheduleReconnect();
    }
  }

  /// 计算指数退避延迟
  int _getReconnectDelay() {
    // 指数退避 + 随机抖动: baseDelay * 2^attempt + random(0~1s)
    final exponential = _baseReconnectDelaySec * pow(2, _reconnectAttempts.clamp(0, 6));
    final delay = min(exponential.toInt(), _maxReconnectDelaySec);
    final jitter = Random().nextInt(1000); // 0~1000ms 随机抖动，避免惊群
    return delay * 1000 + jitter; // 返回毫秒
  }

  /// 调度重连
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();

    if (_manualDisconnect) {
      debugPrint('[WS] Manual disconnect, skip reconnect');
      return;
    }

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('[WS] Max reconnect attempts reached ($_maxReconnectAttempts), giving up');
      _setConnectionState(WsConnectionState.disconnected);
      return;
    }

    final delayMs = _getReconnectDelay();
    _reconnectAttempts++;
    _setConnectionState(WsConnectionState.reconnecting);
    debugPrint('[WS] Reconnecting in ${delayMs}ms (attempt #$_reconnectAttempts/$_maxReconnectAttempts)');

    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () {
      connect();
    });
  }

  /// 清理所有连接资源（不清除消息和待发队列）
  void _cleanup() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _pongTimeoutTimer?.cancel();
    _pongTimeoutTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _subscription = null;

    try {
      _channel?.sink.close();
    } catch (e) {
      // ignore close error
    }
    _channel = null;
  }

  /// 发送 JSON 消息
  void _send(Map<String, dynamic> data) {
    try {
      if (_channel != null) {
        _channel!.sink.add(jsonEncode(data));
      }
    } catch (e) {
      debugPrint('[WS] Send error: $e');
      // 发送失败可能是连接已断，触发重连
      _onDisconnected();
    }
  }

  /// 处理收到的消息
  void _handleMessage(dynamic rawData) {
    try {
      final data = jsonDecode(rawData as String) as Map<String, dynamic>;
      final type = data['type'];

      switch (type) {
        case 'message':
          final msg = ChatMessageModel.fromJson(data);

          // 去重：防止重连后收到重复消息
          if (msg.id != null && _messageIds.contains(msg.id)) {
            debugPrint('[WS] Duplicate message id=${msg.id}, skip');
            break;
          }
          if (msg.id != null) _messageIds.add(msg.id!);

          _messages.add(msg);

          // 限制内存中的消息数量
          if (_messages.length > _maxMessageCacheSize) {
            final removed = _messages.removeAt(0);
            if (removed.id != null) _messageIds.remove(removed.id);
            _hasMore = true; // 移除了旧消息，意味着可以加载更多
          }

          // 聊天页面打开时实时更新已读位置
          if (_pageRefCount > 0) {
            _saveLastReadId();
          }

          notifyListeners();
          break;

        case 'online_count':
          _onlineCount = data['online_count'] ?? 0;
          notifyListeners();
          break;

        case 'auth_success':
          _setConnectionState(WsConnectionState.authenticated);
          debugPrint('[WS] Authenticated: ${data['user']?['nickname']}');
          // 认证成功后，发送待发送队列中的消息
          _flushPendingMessages();
          break;

        case 'auth_fail':
          debugPrint('[WS] Auth failed: ${data['msg']}');
          // 保持 connected 状态，用户可以浏览但不能发送
          break;

        case 'pong':
          _lastPongTime = DateTime.now();
          _pongTimeoutTimer?.cancel(); // 收到 pong，取消超时
          break;

        case 'error':
          debugPrint('[WS] Server error: ${data['msg']}');
          break;

        // ===== 好友 & 私聊 & 群聊 新消息类型 =====
        case 'friend_request':     // 收到好友请求通知
        case 'friend_accepted':    // 好友请求被接受通知
        case 'private_message':    // 收到私聊消息
        case 'group_message':      // 收到群消息
          debugPrint('[WS] Dispatching $type to external handlers');
          final handlers = _externalHandlers[type];
          if (handlers != null) {
            for (final handler in handlers) {
              try {
                handler(data);
              } catch (e) {
                debugPrint('[WS] External handler error for $type: $e');
              }
            }
          }
          break;

        default:
          debugPrint('[WS] Unknown message type: $type');
          // 尝试分发到外部 handler（支持未来扩展）
          final fallbackHandlers = _externalHandlers[type];
          if (fallbackHandlers != null) {
            for (final handler in fallbackHandlers) {
              try {
                handler(data);
              } catch (e) {
                debugPrint('[WS] External handler error for $type: $e');
              }
            }
          }
          break;
      }
    } catch (e) {
      debugPrint('[WS] Parse error: $e');
    }
  }
}
