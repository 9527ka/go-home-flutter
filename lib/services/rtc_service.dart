import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// 腾讯云 RTC Engine 语音通话服务（单例）
///
/// ⚠️ tencent_rtc_sdk 当前已禁用，此为 stub 版本。
/// 所有方法返回安全默认值，不会真正连接 RTC。
/// 重新启用时取消 pubspec.yaml 中的注释并恢复原始实现。
class RtcService {
  RtcService._();
  static final RtcService instance = RtcService._();

  bool _micMuted = false;
  bool _speakerOn = true;

  VoidCallback? onRemoteUserLeave;

  String get debugInfo => 'TRTC SDK disabled';

  bool get inRoom => false;
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
    debugPrint('[RTC] stub: init called — TRTC SDK disabled');
    return false;
  }

  Future<bool> enterRoom(String callId) async {
    debugPrint('[RTC] stub: enterRoom called — TRTC SDK disabled');
    return false;
  }

  Future<void> exitRoom() async {}

  void forceCleanup() {
    onRemoteUserLeave = null;
  }

  Future<void> setMute(bool mute) async {
    _micMuted = mute;
  }

  Future<void> setSpeaker(bool on) async {
    _speakerOn = on;
  }

  Future<void> dispose() async {}
}
