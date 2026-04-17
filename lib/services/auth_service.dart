import '../config/api.dart';
import '../models/user.dart';
import '../utils/storage.dart';
import 'http_client.dart';

class AuthService {
  final _http = HttpClient();

  /// 注册
  Future<Map<String, dynamic>> register({
    required String account,
    required String password,
    int accountType = 1,
  }) async {
    final res = await _http.post(ApiConfig.register, data: {
      'account': account,
      'password': password,
      'account_type': accountType,
    });

    if (res['code'] == 0 && res['data'] != null) {
      await _saveLoginData(res['data']);
    }

    return res;
  }

  /// 登录
  Future<Map<String, dynamic>> login({
    required String account,
    required String password,
  }) async {
    final res = await _http.post(ApiConfig.login, data: {
      'account': account,
      'password': password,
    });

    if (res['code'] == 0 && res['data'] != null) {
      await _saveLoginData(res['data']);
    }

    return res;
  }

  /// Apple 授权登录
  Future<Map<String, dynamic>> appleSignIn({
    required String identityToken,
    required String userIdentifier,
    String? fullName,
    String? email,
  }) async {
    final data = <String, dynamic>{
      'identity_token': identityToken,
      'user_identifier': userIdentifier,
    };
    if (fullName != null && fullName.isNotEmpty) data['full_name'] = fullName;
    if (email != null && email.isNotEmpty) data['email'] = email;

    final res = await _http.post(ApiConfig.appleSignIn, data: data);

    if (res['code'] == 0 && res['data'] != null) {
      await _saveLoginData(res['data']);
    }

    return res;
  }

  /// 游客一键快速登录
  Future<Map<String, dynamic>> quickLogin() async {
    final res = await _http.post(ApiConfig.quickLogin, data: {});

    if (res['code'] == 0 && res['data'] != null) {
      await _saveLoginData(res['data']);
    }

    return res;
  }

  /// 绑定 Apple ID（游客升级）
  Future<Map<String, dynamic>> bindApple({
    required String identityToken,
    required String userIdentifier,
    String? fullName,
    String? email,
  }) async {
    final data = <String, dynamic>{
      'identity_token': identityToken,
      'user_identifier': userIdentifier,
    };
    if (fullName != null && fullName.isNotEmpty) data['full_name'] = fullName;
    if (email != null && email.isNotEmpty) data['email'] = email;

    return await _http.post(ApiConfig.bindApple, data: data);
  }

  /// 修改账号
  Future<Map<String, dynamic>> changeAccount({
    required String account,
    required int accountType,
  }) async {
    return await _http.post(ApiConfig.changeAccount, data: {
      'account': account,
      'account_type': accountType,
    });
  }

  /// 修改密码
  Future<Map<String, dynamic>> changePassword({
    String? oldPassword,
    required String newPassword,
  }) async {
    final data = <String, dynamic>{
      'new_password': newPassword,
    };
    if (oldPassword != null && oldPassword.isNotEmpty) {
      data['old_password'] = oldPassword;
    }
    return await _http.post(ApiConfig.changePassword, data: data);
  }

  /// 获取用户信息
  Future<UserModel?> getProfile() async {
    final res = await _http.get(ApiConfig.profile);
    if (res['code'] == 0 && res['data'] != null) {
      return UserModel.fromJson(res['data']);
    }
    return null;
  }

  /// 更新用户信息
  Future<Map<String, dynamic>> updateProfile({
    String? nickname,
    String? avatar,
    String? contactPhone,
    int? gender,
    String? signature,
  }) async {
    final data = <String, dynamic>{};
    if (nickname != null) data['nickname'] = nickname;
    if (avatar != null) data['avatar'] = avatar;
    if (contactPhone != null) data['contact_phone'] = contactPhone;
    if (gender != null) data['gender'] = gender;
    if (signature != null) data['signature'] = signature;

    return await _http.post(ApiConfig.updateProfile, data: data);
  }

  /// 注销账号
  Future<Map<String, dynamic>> deleteAccount({String? password, bool? confirm}) async {
    final data = <String, dynamic>{};
    if (password != null) data['password'] = password;
    if (confirm != null) data['confirm'] = confirm;
    return await _http.post(ApiConfig.deleteAccount, data: data);
  }

  /// 退出登录
  Future<void> logout() async {
    await StorageUtil.clearToken();
    await StorageUtil.clearUserInfo();
  }

  /// 保存登录数据
  Future<void> _saveLoginData(Map<String, dynamic> data) async {
    if (data['token'] != null) {
      await StorageUtil.saveToken(data['token']);
    }
    if (data['userInfo'] != null) {
      await StorageUtil.saveUserInfo(data['userInfo']);
    }
  }
}
