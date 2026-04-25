import 'package:flutter/widgets.dart';

/// Web 平台 stub — TUICallKit 不支持 Web。
/// 对外 API 必须与 [call_service_native.dart] 完全一致（方法名/参数/返回类型）。
class CallService {
  CallService._();
  static final CallService instance = CallService._();

  bool get loggedIn => false;
  Future<bool>? get loginReady => null;

  List<NavigatorObserver> get navigatorObservers => const [];
  List<LocalizationsDelegate<dynamic>> get localizationsDelegates => const [];

  Future<bool> login({String? nickname, String? avatar}) async => false;

  Future<void> setSelfInfo({required String nickname, required String avatar}) async {}

  Future<void> logout() async {}

  Future<void> prewarmMicPermission() async {}

  Future<bool> callVoice(int peerUserId) async => false;
}
