import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tencent_rtc_sdk/trtc_cloud.dart';
import 'package:tencent_rtc_sdk/trtc_cloud_def.dart';
import 'package:tencent_rtc_sdk/trtc_cloud_listener.dart';
import 'package:tencent_rtc_sdk/tx_device_manager.dart';

/// 腾讯云 RTC Engine 语音通话服务（单例，tencent_rtc_sdk 13.x）
///
/// 从 tencent_trtc_cloud 3.x 迁移到 tencent_rtc_sdk 13.x：
/// - Listener 从 enum 分发改为 class 命名回调
/// - 常量改为 enum：TRTCAppScene.audioCall / TRTCAudioQuality.speech / TXAudioRoute.earpiece
class RtcService {
  RtcService._();
  static final RtcService instance = RtcService._();

  TRTCCloud? _trtc;
  TXDeviceManager? _deviceMgr;
  TRTCCloudListener? _listener;

  int _sdkAppId = 0;
  String _userId = '';
  String _userSig = '';

  bool _inRoom = false;
  bool _micMuted = false;
  bool _speakerOn = true;

  /// enterRoom 的异步完成器
  Completer<int>? _enterRoomCompleter;

  /// 远端用户离开房间
  VoidCallback? onRemoteUserLeave;

  /// 调试信息
  String _debugInfo = '';
  String _lastError = '';
  String get debugInfo => _lastError.isNotEmpty ? '$_debugInfo [$_lastError]' : _debugInfo;

  bool get inRoom => _inRoom;
  bool get micMuted => _micMuted;
  bool get speakerOn => _speakerOn;

  Future<bool> requestMicPermission() async {
    if (kIsWeb) return true;
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> init({
    required int sdkAppId,
    required String userId,
    required String userSig,
  }) async {
    _sdkAppId = sdkAppId;
    _userId   = userId;
    _userSig  = userSig;

    try {
      _trtc ??= await TRTCCloud.sharedInstance();
      _deviceMgr ??= _trtc!.getDeviceManager();
    } catch (e) {
      _debugInfo = 'sharedInstance failed: $e';
      debugPrint('[RTC] $_debugInfo');
      return false;
    }

    if (_listener == null) {
      _listener = TRTCCloudListener(
        onError: (int errCode, String errMsg) {
          _lastError = 'ERR$errCode:$errMsg';
          _debugInfo = 'onError $errCode: $errMsg';
          debugPrint('[RTC] $_debugInfo');
        },
        onWarning: (int warningCode, String warningMsg) {
          debugPrint('[RTC] onWarning $warningCode: $warningMsg');
        },
        onEnterRoom: (int result) {
          debugPrint('[RTC] onEnterRoom result=$result');
          if (result >= 0) {
            _inRoom = true;
            _debugInfo = 'inRoom ok ${result}ms';
          } else {
            _inRoom = false;
            _debugInfo = 'enterRoom err=$result';
          }
          if (_enterRoomCompleter != null && !_enterRoomCompleter!.isCompleted) {
            _enterRoomCompleter!.complete(result);
          }
          _enterRoomCompleter = null;
        },
        onExitRoom: (int reason) {
          debugPrint('[RTC] onExitRoom reason=$reason');
          _debugInfo = 'onExitRoom reason=$reason';
          _inRoom = false;
        },
        onRemoteUserEnterRoom: (String userId) {
          debugPrint('[RTC] onRemoteUserEnterRoom $userId');
          _debugInfo = 'remoteEnter $userId';
        },
        onRemoteUserLeaveRoom: (String userId, int reason) {
          debugPrint('[RTC] onRemoteUserLeaveRoom $userId reason=$reason');
          _debugInfo = 'remoteLeave reason=$reason';
          onRemoteUserLeave?.call();
        },
        onConnectionLost: () {
          _debugInfo = 'connectionLost';
          debugPrint('[RTC] connectionLost');
        },
        onTryToReconnect: () {
          _debugInfo = 'reconnecting...';
          debugPrint('[RTC] tryToReconnect');
        },
        onConnectionRecovery: () {
          _debugInfo = 'reconnected';
          debugPrint('[RTC] connectionRecovery');
        },
      );
      _trtc!.registerListener(_listener!);
    }
    return true;
  }

  /// 进入通话房间。等待 onEnterRoom 回调确认真正进房结果（最多 10s）。
  Future<bool> enterRoom(String callId) async {
    if (_trtc == null || _sdkAppId == 0 || _userSig.isEmpty) {
      _debugInfo = 'enterRoom before init';
      return false;
    }
    if (_inRoom) return true;

    final numericRoomId = _callIdToRoomId(callId);

    final completer = Completer<int>();
    _enterRoomCompleter = completer;

    final params = TRTCParams(
      sdkAppId: _sdkAppId,
      userId: _userId,
      userSig: _userSig,
      roomId: numericRoomId,
      strRoomId: '',
    );

    try {
      _lastError = '';
      debugPrint('[RTC] enterRoom callId=$callId roomId=$numericRoomId userId=$_userId sdkAppId=$_sdkAppId');
      _debugInfo = 'enterRoom roomId=$numericRoomId';
      _trtc!.enterRoom(params, TRTCAppScene.audioCall);
    } catch (e) {
      _debugInfo = 'enterRoom platform error: $e';
      debugPrint('[RTC] $_debugInfo');
      _enterRoomCompleter = null;
      return false;
    }

    int result;
    try {
      result = await completer.future.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      _debugInfo = 'enterRoom timeout 10s';
      debugPrint('[RTC] $_debugInfo');
      _enterRoomCompleter = null;
      try { _trtc!.exitRoom(); } catch (_) {}
      return false;
    }

    if (result < 0) {
      _debugInfo = 'enterRoom failed code=$result';
      debugPrint('[RTC] $_debugInfo');
      return false;
    }

    // 进房成功后才启动音频
    _debugInfo = 'enterRoom ok ${result}ms, starting audio...';
    try {
      _trtc!.startLocalAudio(TRTCAudioQuality.speech);
      await setSpeaker(false);
      _micMuted = false;
      _debugInfo = 'audio started';
    } catch (e) {
      _debugInfo = 'startLocalAudio error: $e';
      debugPrint('[RTC] $_debugInfo');
    }
    return true;
  }

  Future<void> exitRoom() async {
    if (_trtc == null || !_inRoom) return;
    try {
      _trtc!.stopLocalAudio();
      _trtc!.exitRoom();
    } catch (e) {
      debugPrint('[RTC] exitRoom error: $e');
    }
    _inRoom = false;
    if (_enterRoomCompleter != null && !_enterRoomCompleter!.isCompleted) {
      _enterRoomCompleter!.complete(-1);
    }
    _enterRoomCompleter = null;
  }

  void forceCleanup() {
    if (_enterRoomCompleter != null && !_enterRoomCompleter!.isCompleted) {
      _enterRoomCompleter!.complete(-999);
    }
    _enterRoomCompleter = null;
    try { _trtc?.stopLocalAudio(); } catch (_) {}
    try { _trtc?.exitRoom(); } catch (_) {}
    _inRoom = false;
    onRemoteUserLeave = null;
    _debugInfo = '';
    _lastError = '';
  }

  Future<void> setMute(bool mute) async {
    if (_trtc == null) return;
    _trtc!.muteLocalAudio(mute);
    _micMuted = mute;
  }

  Future<void> setSpeaker(bool on) async {
    if (kIsWeb || _deviceMgr == null) return;
    final route = on ? TXAudioRoute.speakerPhone : TXAudioRoute.earpiece;
    _deviceMgr!.setAudioRoute(route);
    _speakerOn = on;
  }

  Future<void> dispose() async {
    if (_inRoom) await exitRoom();
    if (_listener != null && _trtc != null) {
      _trtc!.unRegisterListener(_listener!);
      _listener = null;
    }
    TRTCCloud.destroySharedInstance();
    _trtc = null;
    _deviceMgr = null;
  }

  /// callId → uint32 roomId（确保双方用同一 callId 得到同一 roomId）
  static int _callIdToRoomId(String callId) {
    final hex = callId.replaceAll('-', '');
    if (hex.length >= 8) {
      final first8 = hex.substring(0, 8);
      if (RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(first8)) {
        final id = int.parse(first8, radix: 16) & 0x7FFFFFFF;
        return id == 0 ? 1 : id;
      }
    }
    final id = callId.hashCode.abs() & 0x7FFFFFFF;
    return id == 0 ? 1 : id;
  }
}
