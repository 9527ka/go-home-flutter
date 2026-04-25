import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/call_service.dart';
import '../services/chat_database.dart';
import '../services/push_service.dart';
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

  /// 登录成功后的统一后置处理：
  /// - 初始化本地聊天数据库
  /// - 申请推送权限
  /// - 登录 TUICallKit 长连接（用于接收私聊语音来电）
  ///
  /// 所有子步骤均 fire-and-forget，不阻塞登录流程。
  void _afterLoginSuccess() {
    final u = _user;
    if (u == null) return;
    ChatDatabase.instance.init(u.id);
    PushService.instance.requestPermission();
    unawaited(
      CallService.instance.login(nickname: u.nickname, avatar: u.avatar),
    );
  }

  /// 初始化：检查本地登录状态（单次 SharedPreferences 读取，减少启动延迟）
  Future<void> init() async {
    final auth = await StorageUtil.loadAuthState();

    if (!auth.rememberMe) {
      // 未勾选"记住我"，清除登录状态（并行写入）
      await Future.wait([StorageUtil.clearToken(), StorageUtil.clearUserInfo()]);
      _isLoggedIn = false;
      _initialized = true;
      notifyListeners();
      return;
    }

    _isLoggedIn = auth.isLoggedIn;
    if (_isLoggedIn && auth.userInfo != null) {
      _user = UserModel.fromJson(auth.userInfo!);
      // 以下均为 fire-and-forget，不阻塞启动
      _afterLoginSuccess();
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
        _afterLoginSuccess();
        // IAP 延迟到用户打开充值页时初始化（避免 StoreKit 拖慢启动）
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
        _afterLoginSuccess();
        // IAP 延迟到用户打开充值页时初始化（避免 StoreKit 拖慢启动）
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
        _afterLoginSuccess();
        // IAP 延迟到用户打开充值页时初始化（避免 StoreKit 拖慢启动）
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
        _afterLoginSuccess();
        // IAP 延迟到用户打开充值页时初始化（避免 StoreKit 拖慢启动）
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

  /// 绑定 Apple ID（游客升级）
  Future<String?> bindApple({
    required String identityToken,
    required String userIdentifier,
    String? fullName,
    String? email,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await _authService.bindApple(
        identityToken: identityToken,
        userIdentifier: userIdentifier,
        fullName: fullName,
        email: email,
      );

      if (res['code'] == 0) {
        await refreshProfile();
        return null;
      }
      return res['msg'] ?? '绑定失败';
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
        // 昵称/头像同步到 TUICallKit（来电界面显示）
        unawaited(CallService.instance.setSelfInfo(
          nickname: user.nickname,
          avatar: user.avatar,
        ));
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
        // 注销推送令牌并清除所有本地数据
        await PushService.instance.unregister();
        await CallService.instance.logout();
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
    await PushService.instance.unregister();
    await CallService.instance.logout();
    await _authService.logout();
    await StorageUtil.clearPostsCache();
    await StorageUtil.clearChatCache();
    _user = null;
    _isLoggedIn = false;
    notifyListeners();
  }
}
