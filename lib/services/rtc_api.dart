import '../config/api.dart';
import 'http_client.dart';

/// TRTC 后端接口：拉取 UserSig
class RtcApi {
  final _http = HttpClient();

  /// 拉取当前登录用户的 UserSig
  ///
  /// 返回 `{sdk_app_id, user_id, user_sig, expire}`，失败返回 null
  Future<RtcUserSig?> fetchUserSig() async {
    try {
      final res = await _http.post(ApiConfig.rtcUserSig);
      if (res['code'] == 0 && res['data'] != null) {
        final d = res['data'] as Map<String, dynamic>;
        return RtcUserSig(
          sdkAppId: d['sdk_app_id'] as int,
          userId: '${d['user_id']}',
          userSig: d['user_sig'] as String,
          expire: d['expire'] as int,
        );
      }
    } catch (_) {}
    return null;
  }
}

class RtcUserSig {
  final int sdkAppId;
  final String userId;
  final String userSig;
  final int expire;

  RtcUserSig({
    required this.sdkAppId,
    required this.userId,
    required this.userSig,
    required this.expire,
  });
}
