import 'package:flutter/services.dart';
import '../config/api.dart';
import 'http_client.dart';

/// APNs 推送服务（通过 MethodChannel 与 iOS 原生桥接）
class PushService {
  static final PushService instance = PushService._();
  PushService._();

  static const _channel = MethodChannel('com.gohome/push');
  final _http = HttpClient();
  String? _currentToken;

  /// 初始化：监听原生侧传回的 device token
  void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onToken') {
        final token = call.arguments as String;
        _currentToken = token;
        await _registerOnServer(token);
      }
    });
  }

  /// 请求通知权限并触发 APNs 注册
  Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod('requestPermission');
    } catch (_) {
      // 平台不支持或权限被拒，不影响主流程
    }
  }

  /// 登录后如果已有 token 则重新注册（确保归属正确的用户）
  Future<void> registerIfNeeded() async {
    if (_currentToken != null) {
      await _registerOnServer(_currentToken!);
    }
  }

  /// 退出登录时注销 token
  Future<void> unregister() async {
    if (_currentToken != null) {
      try {
        await _http.post(ApiConfig.deviceUnregisterToken, data: {
          'device_token': _currentToken,
        });
      } catch (_) {}
    }
  }

  Future<void> _registerOnServer(String token) async {
    try {
      await _http.post(ApiConfig.deviceRegisterToken, data: {
        'device_token': token,
        'platform': 'ios',
      });
    } catch (_) {}
  }
}
