import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/api.dart';
import '../utils/storage.dart';

/// WebSocket 连接状态
enum WsConnectionState {
  disconnected, // 未连接
  connecting,   // 连接中
  connected,    // 已连接（未认证）
  authenticated, // 已连接且认证
  reconnecting, // 重连中
}

/// WebSocket 连接生命周期管理
///
/// 负责：连接/断开、重连退避、心跳 ping/pong、认证、连接状态跟踪。
/// 通过回调将事件通知给外部使用者（如 ChatProvider）。
class WsChatManager {
  // ===== 回调 =====

  /// 收到 WebSocket 消息时回调
  final void Function(Map<String, dynamic> data)? onMessage;

  /// 连接状态变化时回调
  final void Function(WsConnectionState state)? onStateChanged;

  WsChatManager({this.onMessage, this.onStateChanged});

  // ===== 配置常量 =====
  static const int _pingIntervalSec = 25;
  static const int _pongTimeoutSec = 10;
  static const int _maxReconnectAttempts = 20;
  static const int _baseReconnectDelaySec = 2;
  static const int _maxReconnectDelaySec = 60;
  static const int _authTimeoutSec = 10;

  // ===== WebSocket 状态 =====
  WsConnectionState _connectionState = WsConnectionState.disconnected;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  // ===== 心跳 & 重连 =====
  Timer? _pingTimer;
  Timer? _pongTimeoutTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _manualDisconnect = false;
  DateTime? _lastPongTime;

  // ===== 待发送队列（断线重连后自动重发） =====
  final List<String> _pendingMessages = [];

  // ===== Getters =====
  WsConnectionState get connectionState => _connectionState;

  bool get isConnected =>
      _connectionState == WsConnectionState.connected ||
      _connectionState == WsConnectionState.authenticated;

  bool get isAuthenticated =>
      _connectionState == WsConnectionState.authenticated;

  int get reconnectAttempts => _reconnectAttempts;
  int get pendingCount => _pendingMessages.length;

  // ===== 连接 =====

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
        _onRawMessage,
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

  /// App 从后台恢复前台
  void onAppResumed() {
    if (!_manualDisconnect && _connectionState == WsConnectionState.disconnected) {
      debugPrint('[WS] App resumed, reconnecting...');
      _reconnectAttempts = 0;
      connect();
    } else if (isConnected) {
      _startHeartbeat();
    }
  }

  /// App 进入后台（停止心跳省电）
  void onAppPaused() {
    _pingTimer?.cancel();
    _pongTimeoutTimer?.cancel();
  }

  // ===== 发送 =====

  /// 发送 JSON 消息到 WebSocket
  void send(Map<String, dynamic> data) {
    try {
      if (_channel != null) {
        _channel!.sink.add(jsonEncode(data));
      }
    } catch (e) {
      debugPrint('[WS] Send error: $e');
      _onDisconnected();
    }
  }

  /// 将消息文本加入待发送队列
  void enqueueMessage(String text) {
    _pendingMessages.add(text);
    debugPrint('[WS] Message queued (pending: ${_pendingMessages.length})');
  }

  /// 发送待发送队列中的消息
  void flushPendingMessages() {
    if (_pendingMessages.isEmpty || !isAuthenticated) return;

    debugPrint('[WS] Flushing ${_pendingMessages.length} pending messages');
    final pending = List<String>.from(_pendingMessages);
    _pendingMessages.clear();

    for (final text in pending) {
      send({'type': 'message', 'content': text});
    }
  }

  // ===== 销毁 =====

  void dispose() {
    _manualDisconnect = true;
    _cleanup();
  }

  // ===== 内部实现 =====

  void _setConnectionState(WsConnectionState state) {
    if (_connectionState == state) return;
    _connectionState = state;
    onStateChanged?.call(state);
  }

  /// 处理原始 WebSocket 数据，解析 JSON 后区分内部协议消息和业务消息
  void _onRawMessage(dynamic rawData) {
    try {
      final data = jsonDecode(rawData as String) as Map<String, dynamic>;
      final type = data['type'];

      switch (type) {
        case 'auth_success':
          _setConnectionState(WsConnectionState.authenticated);
          debugPrint('[WS] Authenticated: ${data['user']?['nickname']}');
          flushPendingMessages();
          // 也通知外部，以便处理 UI 更新
          onMessage?.call(data);
          break;

        case 'auth_fail':
          debugPrint('[WS] Auth failed: ${data['msg']}');
          onMessage?.call(data);
          break;

        case 'pong':
          _lastPongTime = DateTime.now();
          _pongTimeoutTimer?.cancel();
          break;

        default:
          // 其余消息全部交给外部处理
          onMessage?.call(data);
          break;
      }
    } catch (e) {
      debugPrint('[WS] Parse error: $e');
    }
  }

  /// 认证
  Future<void> _authenticate() async {
    final token = await StorageUtil.getToken();
    if (token == null || token.isEmpty) {
      debugPrint('[WS] No token, skip auth');
      return;
    }

    send({'type': 'auth', 'token': token});

    // 认证超时检测
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

        send({'type': 'ping'});

        _pongTimeoutTimer?.cancel();
        _pongTimeoutTimer = Timer(
          const Duration(seconds: _pongTimeoutSec),
          () {
            debugPrint('[WS] Pong timeout! Last pong: $_lastPongTime');
            _onDisconnected();
          },
        );
      },
    );
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
    final exponential = _baseReconnectDelaySec * pow(2, _reconnectAttempts.clamp(0, 6));
    final delay = min(exponential.toInt(), _maxReconnectDelaySec);
    final jitter = Random().nextInt(1000);
    return delay * 1000 + jitter;
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

  /// 清理所有连接资源（不清除待发队列）
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
}
