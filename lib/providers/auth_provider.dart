import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../utils/storage.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _user;
  bool _isLoading = false;
  bool _isLoggedIn = false;
  bool _initialized = false;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  bool get initialized => _initialized;

  /// 初始化：检查本地登录状态
  Future<void> init() async {
    final rememberMe = await StorageUtil.getRememberMe();
    if (!rememberMe) {
      // 未勾选"记住我"，清除登录状态
      await StorageUtil.clearToken();
      await StorageUtil.clearUserInfo();
      _isLoggedIn = false;
      _initialized = true;
      notifyListeners();
      return;
    }

    _isLoggedIn = await StorageUtil.isLoggedIn();
    if (_isLoggedIn) {
      final info = await StorageUtil.getUserInfo();
      if (info != null) {
        _user = UserModel.fromJson(info);
      }
    }
    _initialized = true;
    notifyListeners();
  }

  /// 注册
  Future<String?> register(String account, String password, int accountType) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _authService.register(
        account: account,
        password: password,
        accountType: accountType,
      );

      if (res['code'] == 0) {
        _isLoggedIn = true;
        if (res['data']?['userInfo'] != null) {
          _user = UserModel.fromJson(res['data']['userInfo']);
        }
        notifyListeners();
        return null; // 成功
      }
      return res['msg'] ?? '注册失败';
    } catch (e) {
      return '网络异常，请重试';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 登录
  Future<String?> login(String account, String password, {bool rememberMe = true}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _authService.login(
        account: account,
        password: password,
      );

      if (res['code'] == 0) {
        await StorageUtil.saveRememberMe(rememberMe);
        _isLoggedIn = true;
        if (res['data']?['userInfo'] != null) {
          _user = UserModel.fromJson(res['data']['userInfo']);
        }
        notifyListeners();
        return null; // 成功
      }
      return res['msg'] ?? '登录失败';
    } catch (e) {
      return '网络异常，请重试';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Apple 授权登录
  Future<String?> appleSignIn({
    required String identityToken,
    required String userIdentifier,
    String? fullName,
    String? email,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _authService.appleSignIn(
        identityToken: identityToken,
        userIdentifier: userIdentifier,
        fullName: fullName,
        email: email,
      );

      if (res['code'] == 0) {
        _isLoggedIn = true;
        if (res['data']?['userInfo'] != null) {
          _user = UserModel.fromJson(res['data']['userInfo']);
        }
        notifyListeners();
        return null; // 成功
      }
      return res['msg'] ?? 'Apple 登录失败';
    } catch (e) {
      return '网络异常，请重试';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 游客一键快速登录
  Future<String?> quickLogin() async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _authService.quickLogin();

      if (res['code'] == 0) {
        await StorageUtil.saveRememberMe(true);
        _isLoggedIn = true;
        if (res['data']?['userInfo'] != null) {
          _user = UserModel.fromJson(res['data']['userInfo']);
        }
        notifyListeners();
        return null; // 成功
      }
      return res['msg'] ?? '快速登录失败';
    } catch (e) {
      return '网络异常，请重试';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 修改账号
  Future<String?> changeAccount(String account, int accountType) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _authService.changeAccount(
        account: account,
        accountType: accountType,
      );

      if (res['code'] == 0) {
        // 刷新用户信息
        await refreshProfile();
        return null;
      }
      return res['msg'] ?? '修改失败';
    } catch (e) {
      return '网络异常，请重试';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 修改密码
  Future<String?> changePassword({String? oldPassword, required String newPassword}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _authService.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );

      if (res['code'] == 0) {
        return null;
      }
      return res['msg'] ?? '修改失败';
    } catch (e) {
      return '网络异常，请重试';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 更新个人资料（调用后刷新本地状态）
  Future<void> refreshProfile() async {
    try {
      final user = await _authService.getProfile();
      if (user != null) {
        _user = user;
        // 同步到本地存储
        await StorageUtil.saveUserInfo(user.toJson());
        notifyListeners();
      }
    } catch (e) {
      // ignore
    }
  }

  /// 注销账号
  Future<String?> deleteAccount({String? password, bool? confirm}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _authService.deleteAccount(
        password: password,
        confirm: confirm,
      );

      if (res['code'] == 0) {
        // 清除所有本地数据
        await _authService.logout();
        _user = null;
        _isLoggedIn = false;
        notifyListeners();
        return null; // 成功
      }
      return res['msg'] ?? '注销失败';
    } catch (e) {
      return '网络异常，请重试';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 退出登录
  Future<void> logout() async {
    await _authService.logout();
    await StorageUtil.clearPostsCache();
    await StorageUtil.clearChatCache();
    _user = null;
    _isLoggedIn = false;
    notifyListeners();
  }
}
