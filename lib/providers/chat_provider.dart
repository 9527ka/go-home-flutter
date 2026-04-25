import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../utils/storage.dart';
import 'chat_ws_manager.dart';
import 'chat_message_handler.dart';
import 'chat_message_sender.dart';

// Re-export so that existing `import 'chat_provider.dart'` still provides the enum.
export 'chat_ws_manager.dart' show WsConnectionState;

class ChatProvider extends ChangeNotifier with WidgetsBindingObserver {
  final ChatService _chatService = ChatService();

  // ===== 组合模块 =====
  late final WsChatManager _ws;
  late final ChatMessageHandler _handler;
  late final ChatMessageSender _sender;

  // ===== UI 状态 =====
  bool _isLoading = false;
  int _onlineCount = 0;

  // ===== 页面引用计数（控制 WS 生命周期） =====
  int _pageRefCount = 0;

  // ===== 未读消息红点 =====
  bool _hasUnread = false;

  // ===== Getters（保持原有公共 API） =====
  List<ChatMessageModel> get messages => _handler.messages;
  bool get isLoading => _isLoading;
  bool get hasMore => _handler.hasMore;
  int get onlineCount => _onlineCount;
  WsConnectionState get connectionState => _ws.connectionState;
  bool get isConnected => _ws.isConnected;
  bool get isAuthenticated => _ws.isAuthenticated;
  int get reconnectAttempts => _ws.reconnectAttempts;
  int get pendingCount => _ws.pendingCount;
  bool get hasUnread => _hasUnread;

  // ===== 初始化 & 销毁 =====

  ChatProvider() {
    _ws = WsChatManager(
      onMessage: _onWsMessage,
      onStateChanged: _onWsStateChanged,
    );
    _handler = ChatMessageHandler();
    _sender = ChatMessageSender(_ws);

    // 消息列表变化时触发 UI 刷新 + 实时更新已读位置
    _handler.onMessagesChanged = () {
      if (_pageRefCount > 0) {
        _saveLastReadId();
      }
      notifyListeners();
    };

    _handler.onOnlineCountChanged = (count) {
      _onlineCount = count;
      notifyListeners();
    };

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ws.dispose();
    super.dispose();
  }

  // ===== 页面生命周期管理 =====

  /// ChatPage 进入时调用，开始连接
  void onPageEnter() {
    _pageRefCount++;
    if (_hasUnread) {
      _hasUnread = false;
      notifyListeners();
    }
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
      _ws.disconnect();
      _onlineCount = 0;
      _saveChatCacheAsync();
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

  /// 监听 App 前后台切换
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_pageRefCount <= 0) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _ws.onAppResumed();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _ws.onAppPaused();
        break;
      default:
        break;
    }
  }

  // ===== 历史消息 =====

  /// 从本地缓存加载聊天记录（用于瞬间显示）
  Future<void> loadFromCache() async {
    if (_handler.messages.isNotEmpty) return;
    try {
      final cached = await StorageUtil.getChatCache();
      if (cached != null && cached.isNotEmpty) {
        final List<dynamic> list = jsonDecode(cached);
        _handler.setMessages(
          list.map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>)).toList(),
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[Chat] loadFromCache error: $e');
    }
  }

  /// 加载历史消息
  Future<void> loadHistory() async {
    if (_isLoading) return;

    await loadFromCache();

    _isLoading = true;
    notifyListeners();

    try {
      final data = await _chatService.getHistory(limit: 50);
      final list = (data['list'] as List?)
              ?.map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];

      _handler.setMessages(list);
      _handler.hasMore = data['has_more'] == true;

      _saveLastReadId();
      _saveChatCacheAsync();
    } catch (e) {
      debugPrint('[WS] loadHistory error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 清空本地聊天记录
  void clearMessages() {
    _handler.clearMessages();
    StorageUtil.clearChatCache();
    notifyListeners();
  }

  /// 切换账号/登出时调用：彻底清空本地 WS 状态、消息缓存和未读标记
  Future<void> resetSession() async {
    // 断开 WebSocket 连接（避免新账号还在接收旧连接的消息）
    try {
      _ws.disconnect();
    } catch (_) {}
    _pageRefCount = 0;
    _hasUnread = false;
    _isLoading = false;
    _onlineCount = 0;
    _handler.clearMessages();
    await StorageUtil.clearChatCache();
    await StorageUtil.saveLastReadChatId(0);
    notifyListeners();
  }

  /// 加载更早的消息
  Future<void> loadMore() async {
    if (_isLoading || !_handler.hasMore || _handler.messages.isEmpty) return;
    _isLoading = true;
    notifyListeners();

    try {
      final firstId = _handler.messages.first.id;
      if (firstId == null) return;

      final data = await _chatService.getHistory(beforeId: firstId, limit: 50);
      final list = (data['list'] as List?)
              ?.map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];

      _handler.insertMessagesAtStart(list);
      _handler.hasMore = data['has_more'] == true;
    } catch (e) {
      debugPrint('[WS] loadMore error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ===== WebSocket 连接（委托给 WsChatManager） =====

  Future<void> connect() => _ws.connect();
  void disconnect() => _ws.disconnect();
  void manualReconnect() => _ws.manualReconnect();

  // ===== 外部消息 handler 注册（保持原有 API） =====

  void registerHandler(String type, void Function(Map<String, dynamic>) handler) {
    _handler.registerHandler(type, handler);
  }

  void removeHandler(String type, void Function(Map<String, dynamic>) handler) {
    _handler.removeHandler(type, handler);
  }

  /// 发送任意自定义 WS 指令（扩展占位）
  void sendRaw(Map<String, dynamic> data) => _ws.send(data);

  // ===== 发送消息（委托给 ChatMessageSender） =====

  void sendMessage(String content) => _sender.sendMessage(content);

  void sendMediaMessage({
    required String msgType,
    required String mediaUrl,
    String thumbUrl = '',
    String content = '',
    Map<String, dynamic>? mediaInfo,
  }) =>
      _sender.sendMediaMessage(
        msgType: msgType,
        mediaUrl: mediaUrl,
        thumbUrl: thumbUrl,
        content: content,
        mediaInfo: mediaInfo,
      );

  void sendPrivateMessage(int toUserId, String content, {String? clientMsgId}) =>
      _sender.sendPrivateMessage(toUserId, content, clientMsgId: clientMsgId);

  void sendPrivateMediaMessage({
    required int toUserId,
    required String msgType,
    required String mediaUrl,
    String thumbUrl = '',
    String content = '',
    Map<String, dynamic>? mediaInfo,
    String? clientMsgId,
  }) =>
      _sender.sendPrivateMediaMessage(
        toUserId: toUserId,
        msgType: msgType,
        mediaUrl: mediaUrl,
        thumbUrl: thumbUrl,
        content: content,
        mediaInfo: mediaInfo,
        clientMsgId: clientMsgId,
      );

  void sendGroupMessage(int groupId, String content, {List<int>? mentions}) =>
      _sender.sendGroupMessage(groupId, content, mentions: mentions);

  void sendGroupMediaMessage({
    required int groupId,
    required String msgType,
    required String mediaUrl,
    String thumbUrl = '',
    String content = '',
    Map<String, dynamic>? mediaInfo,
  }) =>
      _sender.sendGroupMediaMessage(
        groupId: groupId,
        msgType: msgType,
        mediaUrl: mediaUrl,
        thumbUrl: thumbUrl,
        content: content,
        mediaInfo: mediaInfo,
      );

  void sendRedPacketMessage(int redPacketId) =>
      _sender.sendRedPacketMessage(redPacketId);

  void sendPrivateRedPacketMessage(int toUserId, int redPacketId, {String? clientMsgId}) =>
      _sender.sendPrivateRedPacketMessage(toUserId, redPacketId, clientMsgId: clientMsgId);

  void sendGroupRedPacketMessage(int groupId, int redPacketId) =>
      _sender.sendGroupRedPacketMessage(groupId, redPacketId);

  // ===== 内部回调 =====

  /// WsChatManager 收到业务消息时的回调
  void _onWsMessage(Map<String, dynamic> data) {
    _handler.handleMessage(data);
  }

  /// WsChatManager 连接状态变化时的回调
  void _onWsStateChanged(WsConnectionState state) {
    notifyListeners();
  }

  // ===== 缓存 & 已读 =====

  void _saveChatCacheAsync() {
    try {
      final jsonStr = jsonEncode(_handler.messages.map((m) => m.toJson()).toList());
      StorageUtil.saveChatCache(jsonStr);
    } catch (e) {
      debugPrint('[Chat] saveChatCache error: $e');
    }
  }

  Future<void> _saveLastReadId() async {
    final msgs = _handler.messages;
    if (msgs.isNotEmpty) {
      for (var i = msgs.length - 1; i >= 0; i--) {
        final id = msgs[i].id;
        if (id != null && id > 0) {
          await StorageUtil.saveLastReadChatId(id);
          break;
        }
      }
    }
  }
}
