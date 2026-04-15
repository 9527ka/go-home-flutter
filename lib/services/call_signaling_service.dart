import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:uuid/uuid.dart';
import '../pages/call/incoming_call_page.dart';
import '../pages/call/in_call_page.dart';
import '../providers/chat_provider.dart';
import 'call_audio_service.dart';
import 'http_client.dart';
import 'rtc_api.dart';
import 'rtc_service.dart';

/// 通话状态
enum CallState {
  idle,
  outgoing,  // 主叫响铃等待中
  incoming,  // 收到来电，等待接听/拒绝
  connecting,// 双方都同意了，正在进入 TRTC 房间
  connected, // 通话中
}

/// 发起通话失败的具体原因（用于 UI 显示精确文案）
enum CallInviteError {
  none,
  alreadyInCall,        // 当前已在另一通话
  wsNotAuthenticated,   // WebSocket 未连接 / 未认证
  micPermissionDenied,  // 麦克风权限被拒
  userSigFailed,        // 后端拉 UserSig 失败（接口未通 / 未配置 / 未登录）
  rtcInitFailed,        // TRTC SDK 初始化失败
}

/// 通话信令服务（全局单例）
///
/// 职责：
/// - 订阅 WebSocket `call_signal` 消息，维护本地通话状态机
/// - 发起 invite / accept / decline / cancel / hangup / timeout 信令
/// - 控制 RTC 房间进出（通过 [RtcService]）
/// - 导航来电页 / 通话中页（通过 [HttpClient.navigatorKey]）
///
/// 使用：
/// 1. `App` 启动并完成登录后调用 `attach(chatProvider)` 绑定 WS
/// 2. 主叫从 UI 调用 `invite(toUserId, friendNickname, friendAvatar)`
/// 3. 被叫收到 call_signal invite 时自动弹出 [IncomingCallPage]
/// 4. 接听/拒绝/挂断由对应页面调 `accept()` / `decline()` / `hangup()`
class CallSignalingService extends ChangeNotifier {
  CallSignalingService._();
  static final CallSignalingService instance = CallSignalingService._();

  /// 主叫响铃超时（秒），需与服务端 [CallSignalingHandler::CALL_RING_TIMEOUT_SEC] 保持一致
  static const int ringTimeoutSec = 60;

  ChatProvider? _chatProvider;
  final _uuid = const Uuid();

  // ===== 当前通话状态 =====
  CallState _state = CallState.idle;
  String _callId = '';
  int _peerId = 0;
  String _peerNickname = '';
  String _peerAvatar = '';
  bool _isCaller = false;
  DateTime? _startedAt;
  Timer? _ringTimer;
  Timer? _durationTimer;

  // ===== Getters =====
  CallState get state => _state;
  String get callId => _callId;
  int get peerId => _peerId;
  String get peerNickname => _peerNickname;
  String get peerAvatar => _peerAvatar;
  bool get isCaller => _isCaller;
  bool get isInCall => _state != CallState.idle;

  /// 调试信息（临时，便于定位通话断开原因）
  String _debugInfo = '';
  String get debugInfo => '$_debugInfo | RTC: ${RtcService.instance.debugInfo}';

  /// 通话时长（秒），仅 connected 状态有意义
  int get durationSec {
    if (_startedAt == null) return 0;
    return DateTime.now().difference(_startedAt!).inSeconds;
  }

  // ===== 生命周期 =====

  void attach(ChatProvider chatProvider) {
    if (_chatProvider == chatProvider) return;
    _chatProvider?.removeHandler('call_signal', _onSignal);
    _chatProvider = chatProvider;
    chatProvider.registerHandler('call_signal', _onSignal);
    debugPrint('[Call] attached to ChatProvider (authenticated=${chatProvider.isAuthenticated})');
  }

  void detach() {
    _chatProvider?.removeHandler('call_signal', _onSignal);
    _chatProvider = null;
    _resetState();
  }

  /// 确保 chatProvider 已绑定；在发起通话前由调用方传入当前 context 的 ChatProvider
  void ensureAttached(ChatProvider chatProvider) {
    if (_chatProvider == null || _chatProvider != chatProvider) {
      debugPrint('[Call] ensureAttached: re-attaching (was ${_chatProvider == null ? "null" : "stale"})');
      attach(chatProvider);
    }
  }

  @override
  void dispose() {
    // 单例：ChangeNotifierProxyProvider 可能在 widget 重建时调用 dispose()
    // 不调 super.dispose()（避免清空 listeners 导致后续 notifyListeners 失效）
    // 不调 detach()（保留 _chatProvider 引用，ensureAttached 会在下次使用前修正）
    debugPrint('[Call] dispose called on singleton — ignored to preserve state');
  }

  // ===== 调试：独立 TRTC 进房测试 =====

  /// 纯 TRTC 进房测试（绕过所有通话信令，仅测 SDK 能否进房）
  /// 从私聊页面调用，测试完后自动退出
  Future<void> testEnterRoom() async {
    Fluttertoast.showToast(msg: '[Test] 开始 TRTC 进房测试...', toastLength: Toast.LENGTH_SHORT, gravity: ToastGravity.TOP);

    // 1. 拉 UserSig
    final sig = await RtcApi().fetchUserSig();
    if (sig == null) {
      Fluttertoast.showToast(msg: '[Test] fetchUserSig FAILED', toastLength: Toast.LENGTH_LONG, gravity: ToastGravity.TOP, backgroundColor: Colors.red);
      return;
    }
    Fluttertoast.showToast(
      msg: '[Test] sig ok: appId=${sig.sdkAppId} userId=${sig.userId} sigLen=${sig.userSig.length}',
      toastLength: Toast.LENGTH_LONG, gravity: ToastGravity.TOP,
    );
    await Future.delayed(const Duration(seconds: 2));

    // 2. 初始化 TRTC
    final initOk = await RtcService.instance.init(
      sdkAppId: sig.sdkAppId,
      userId: sig.userId,
      userSig: sig.userSig,
    );
    if (!initOk) {
      Fluttertoast.showToast(msg: '[Test] TRTC init FAILED', toastLength: Toast.LENGTH_LONG, gravity: ToastGravity.TOP, backgroundColor: Colors.red);
      return;
    }

    // 3. 进房（测试房间号 99999）
    Fluttertoast.showToast(msg: '[Test] entering room 99999...', toastLength: Toast.LENGTH_SHORT, gravity: ToastGravity.TOP);
    final ok = await RtcService.instance.enterRoom('test-room-99999');
    final info = RtcService.instance.debugInfo;

    if (ok) {
      Fluttertoast.showToast(
        msg: '[Test] SUCCESS! $info',
        toastLength: Toast.LENGTH_LONG, gravity: ToastGravity.TOP,
        backgroundColor: Colors.green,
      );
      // 等 3 秒后退房
      await Future.delayed(const Duration(seconds: 3));
      await RtcService.instance.exitRoom();
    } else {
      Fluttertoast.showToast(
        msg: '[Test] FAILED! $info',
        toastLength: Toast.LENGTH_LONG, gravity: ToastGravity.TOP,
        backgroundColor: Colors.red,
      );
    }
    RtcService.instance.forceCleanup();
  }

  // ===== 主叫：发起通话 =====

  /// 发起语音通话；返回具体失败原因（[CallInviteError.none] 表示成功）
  Future<CallInviteError> invite({
    required int toUserId,
    required String peerNickname,
    required String peerAvatar,
  }) async {
    if (_state != CallState.idle) {
      debugPrint('[Call] already in a call');
      return CallInviteError.alreadyInCall;
    }
    if (_chatProvider == null) {
      debugPrint('[Call] chatProvider is null — ensureAttached was not called before invite');
      return CallInviteError.wsNotAuthenticated;
    }

    // 麦克风权限（首次弹系统对话框，后续秒返回）
    final micOk = await RtcService.instance.requestMicPermission();
    if (!micOk) {
      debugPrint('[Call] mic permission denied');
      return CallInviteError.micPermissionDenied;
    }

    // ── 立即显示拨号界面，减少用户感知延迟 ──
    _callId = _uuid.v4();
    _peerId = toUserId;
    _peerNickname = peerNickname;
    _peerAvatar = peerAvatar;
    _isCaller = true;
    _state = CallState.outgoing;
    notifyListeners();
    _openInCallPage();
    CallAudioService.instance.playRingback();

    // ── 以下异步操作在"呼叫中"界面背后完成 ──

    // WS 认证检查
    if (!_chatProvider!.isAuthenticated) {
      final prevState = _chatProvider!.connectionState;
      debugPrint('[Call] ws not authenticated (state=$prevState), forcing reconnect...');
      _chatProvider!.manualReconnect();
      for (int i = 0; i < 50; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (_chatProvider!.isAuthenticated) break;
      }
      if (!_chatProvider!.isAuthenticated) {
        debugPrint('[Call] ws still not authenticated after 5s (prev=$prevState, now=${_chatProvider!.connectionState})');
        _resetState();
        return CallInviteError.wsNotAuthenticated;
      }
      debugPrint('[Call] ws authenticated after waiting');
    }

    // 预拉 UserSig
    final sig = await RtcApi().fetchUserSig();
    if (sig == null) {
      debugPrint('[Call] fetchUserSig failed');
      _resetState();
      return CallInviteError.userSigFailed;
    }
    if (_state != CallState.outgoing) return CallInviteError.none; // 用户已取消

    // 初始化 TRTC
    final initOk = await RtcService.instance.init(
      sdkAppId: sig.sdkAppId,
      userId: sig.userId,
      userSig: sig.userSig,
    );
    if (!initOk) {
      debugPrint('[Call] RtcService.init failed');
      _resetState();
      return CallInviteError.rtcInitFailed;
    }
    if (_state != CallState.outgoing) return CallInviteError.none; // 用户已取消

    // 发送邀请信令
    _chatProvider!.sendRaw({
      'type'     : 'call_signal',
      'action'   : 'invite',
      'call_id'  : _callId,
      'to_id'    : toUserId,
      'call_type': 'voice',
    });

    _startRingTimeout();
    return CallInviteError.none;
  }

  /// 主叫取消（对方接听前）
  void cancel() {
    if (_state != CallState.outgoing || !_isCaller) return;
    // invite 已发出才向服务端发 cancel（_ringTimer 在 invite 信令发送后才启动）
    if (_ringTimer != null) {
      _chatProvider?.sendRaw({
        'type'   : 'call_signal',
        'action' : 'cancel',
        'call_id': _callId,
        'to_id'  : _peerId,
      });
    }
    _resetState();
  }

  // ===== 被叫：应答 =====

  Future<void> accept() async {
    if (_state != CallState.incoming) return;
    final micOk = await RtcService.instance.requestMicPermission();
    if (!micOk) {
      decline();
      return;
    }
    final ok = await _ensureRtcReady();
    if (!ok) { decline(); return; }

    _state = CallState.connecting;
    notifyListeners();
    _chatProvider?.sendRaw({
      'type'   : 'call_signal',
      'action' : 'accept',
      'call_id': _callId,
      'to_id'  : _peerId,
    });
    await _joinRoomAndMarkConnected();
  }

  void decline() {
    if (_state != CallState.incoming) return;
    _chatProvider?.sendRaw({
      'type'   : 'call_signal',
      'action' : 'decline',
      'call_id': _callId,
      'to_id'  : _peerId,
    });
    _resetState();
  }

  /// 任意方挂断（已接通状态）
  Future<void> hangup() async {
    if (_state == CallState.idle) return;
    // connected 状态发 hangup；outgoing 状态主叫等同 cancel
    if (_state == CallState.outgoing && _isCaller) {
      cancel();
      return;
    }
    final hangupCallId = _callId;
    final hangupPeerId = _peerId;
    _chatProvider?.sendRaw({
      'type'   : 'call_signal',
      'action' : 'hangup',
      'call_id': hangupCallId,
      'to_id'  : hangupPeerId,
    });
    await RtcService.instance.exitRoom();
    if (_state == CallState.idle) return; // 已被 _onPeerTerminate 重置
    _resetState();
  }

  // ===== 通话控制（转发给 RtcService） =====

  Future<void> setMute(bool mute) async {
    await RtcService.instance.setMute(mute);
    notifyListeners();
  }

  Future<void> setSpeaker(bool on) async {
    await RtcService.instance.setSpeaker(on);
    notifyListeners();
  }

  bool get micMuted => RtcService.instance.micMuted;
  bool get speakerOn => RtcService.instance.speakerOn;

  // =====================================================================
  //  内部：信令处理
  // =====================================================================

  void _onSignal(Map<String, dynamic> data) {
    final action = (data['action'] ?? '') as String;
    final callId = (data['call_id'] ?? '') as String;
    if (action.isEmpty || callId.isEmpty) return;

    debugPrint('[Call] recv action=$action call_id=$callId state=$_state');

    switch (action) {
      case 'invite':
        _onInvite(data);
        break;
      case 'invite_ok':
        // 主叫已被服务端受理，继续等 accept/decline/timeout
        break;
      case 'accept':
        _onPeerAccept(callId);
        break;
      case 'decline':
      case 'callee_offline':
      case 'busy':
      case 'timeout':
      case 'cancel':
      case 'hangup':
        _onPeerTerminate(callId, action);
        break;
    }
  }

  void _onInvite(Map<String, dynamic> data) {
    if (_state != CallState.idle) {
      // 已在通话中 — 服务端也会校验 busy，这里做兜底
      return;
    }
    _callId       = (data['call_id'] ?? '') as String;
    _peerId       = (data['from_id'] is int) ? data['from_id'] as int : 0;
    _peerNickname = (data['from_nickname'] ?? '') as String;
    _peerAvatar   = (data['from_avatar'] ?? '') as String;
    _isCaller     = false;
    _state        = CallState.incoming;
    notifyListeners();

    CallAudioService.instance.playRingtone();
    _startRingTimeout(); // 被叫侧也加一个保底超时，防止服务端异常
    _openIncomingCallPage();
  }

  void _onPeerAccept(String callId) async {
    if (_state != CallState.outgoing || callId != _callId) return;
    _state = CallState.connecting;
    notifyListeners();
    try {
      await _joinRoomAndMarkConnected();
    } catch (e) {
      debugPrint('[Call] _onPeerAccept error: $e');
      if (_state != CallState.idle) _resetState();
    }
  }

  void _onPeerTerminate(String callId, String reason) async {
    if (callId != _callId || _state == CallState.idle) return;
    _debugInfo = 'peerTerminate: $reason';
    debugPrint('[Call] peer terminated reason=$reason');
    try {
      await RtcService.instance.exitRoom();
    } catch (e) {
      debugPrint('[Call] exitRoom in _onPeerTerminate error: $e');
    }
    if (_state == CallState.idle) return; // 已被 hangup() 重置
    _resetState();
  }

  // =====================================================================
  //  内部：RTC 衔接
  // =====================================================================

  Future<bool> _ensureRtcReady() async {
    try {
      final sig = await RtcApi().fetchUserSig();
      if (sig == null) return false;
      return await RtcService.instance.init(
        sdkAppId: sig.sdkAppId,
        userId: sig.userId,
        userSig: sig.userSig,
      );
    } catch (e) {
      debugPrint('[Call] _ensureRtcReady failed: $e');
      return false;
    }
  }

  Future<void> _joinRoomAndMarkConnected() async {
    RtcService.instance.onRemoteUserLeave = () {
      // 对方异常断线 — 等同 hangup
      hangup();
    };
    // 先停铃声/回铃音，避免 just_audio 与 TRTC 音频会话冲突（Android）
    await CallAudioService.instance.stop();
    // enterRoom 等待 onEnterRoom 回调确认真正进房结果（最多 10s）
    _debugInfo = 'entering room...';
    final entered = await RtcService.instance.enterRoom(_callId);
    if (!entered) {
      _debugInfo = 'enterRoom FAILED';
      debugPrint('[Call] enterRoom failed — hangup');
      await hangup();
      return;
    }
    _debugInfo = 'room entered';
    if (_state == CallState.idle) return; // 进房期间被对端终止
    _state = CallState.connected;
    _startedAt = DateTime.now();
    _ringTimer?.cancel();
    _startDurationTimer();
    notifyListeners();
  }

  // =====================================================================
  //  内部：计时 / 导航 / 重置
  // =====================================================================

  void _startRingTimeout() {
    _ringTimer?.cancel();
    _ringTimer = Timer(const Duration(seconds: ringTimeoutSec), () {
      if (_state == CallState.outgoing && _isCaller) {
        _chatProvider?.sendRaw({
          'type'   : 'call_signal',
          'action' : 'timeout',
          'call_id': _callId,
          'to_id'  : _peerId,
        });
      }
      if (_state == CallState.incoming || _state == CallState.outgoing) {
        _resetState();
      }
    });
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
  }

  void _openIncomingCallPage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = HttpClient.navigatorKey.currentState;
      if (nav == null || _state != CallState.incoming) return;
      nav.push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const IncomingCallPage(),
      ));
    });
  }

  void _openInCallPage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final nav = HttpClient.navigatorKey.currentState;
      if (nav == null || _state == CallState.idle) return;
      nav.push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const InCallPage(),
      ));
    });
  }

  void _resetState() {
    // 弹出调试 Toast（页面关闭后仍可看到退出原因）
    final info = debugInfo;
    if (info.isNotEmpty) {
      Fluttertoast.showToast(
        msg: '[Call Exit] $info',
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.black87,
        textColor: Colors.white,
        fontSize: 12,
      );
    }
    CallAudioService.instance.stop();
    // 强制清理 TRTC：取消进房等待 + 退出残留房间，防止泄露影响下次通话
    RtcService.instance.forceCleanup();
    _ringTimer?.cancel();
    _durationTimer?.cancel();
    _state = CallState.idle;
    _callId = '';
    _peerId = 0;
    _peerNickname = '';
    _peerAvatar = '';
    _isCaller = false;
    _startedAt = null;
    notifyListeners();
  }
}

