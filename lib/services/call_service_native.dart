import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tencent_calls_uikit/tencent_calls_uikit.dart';
import '../config/api.dart';
import '../utils/url_helper.dart';
import 'http_client.dart';

/// TUICallKit 通话服务（单例）
///
/// 生命周期：
/// 1. App 启动 / 用户登录成功后调 [login]，TUICallKit 维持长连接接收来电
/// 2. 主叫在私聊页点通话按钮 → [callVoice]；SDK 自动打开拨号 UI 并处理整个通话
/// 3. 退出登录时调 [logout] 断开长连接
/// 4. 资料更新（改昵称/头像）后调 [setSelfInfo] 同步到通话界面
///
/// 设计要点：
/// - `login` 返回同一 Future（并发调用共享），由 [loginReady] 对外暴露；
///   [callVoice] 会 `await loginReady`，保证首次点击前长连接已建立
/// - 首次进入私聊页时预暖麦克风权限，避免第一次 `calls()` 被系统权限弹窗阻塞
class CallService {
  CallService._();
  static final CallService instance = CallService._();

  final HttpClient _http = HttpClient();

  bool _loggedIn = false;
  Future<bool>? _loginFuture;

  bool get loggedIn => _loggedIn;

  /// 当前登录过程的 Future（尚未开始登录则为 null）。
  /// UI 可 `await` 它，登录尚未完成时阻塞，避免首次点击 calls() 前 SDK 未就绪。
  Future<bool>? get loginReady => _loginFuture;

  /// MaterialApp 需要注入的 NavigatorObserver（来电 / 通话页由 SDK 自行 push）
  List<NavigatorObserver> get navigatorObservers => [TUICallKit.navigatorObserver];

  /// MaterialApp 需要注入的本地化委托（通话界面的中英文）
  List<LocalizationsDelegate<dynamic>> get localizationsDelegates =>
      [AtomicLocalizations.delegate];

  // ==========================================================================
  //  登录 / 登出
  // ==========================================================================

  /// 用户登录 TUICallKit 长连接。并发调用会共享同一 Future。
  ///
  /// 内部流程：
  /// 1. 后端 /api/rtc/user-sig 拉 UserSig
  /// 2. TUICallKit.login（内部初始化 TRTC + TIMCloud + 建立长连接，首次 1~3s）
  /// 3. setSelfInfo 同步昵称头像
  Future<bool> login({String? nickname, String? avatar}) {
    if (_loggedIn) return Future.value(true);
    final existing = _loginFuture;
    if (existing != null) return existing;
    final future = _doLogin(nickname: nickname, avatar: avatar);
    _loginFuture = future;
    // 登录失败时清空 future 允许下次重试
    future.then((ok) {
      if (!ok) _loginFuture = null;
    });
    return future;
  }

  Future<bool> _doLogin({String? nickname, String? avatar}) async {
    try {
      final res = await _http.post(ApiConfig.rtcUserSig);
      if (res['code'] != 0 || res['data'] == null) {
        debugPrint('[CallService] fetch UserSig failed: ${res['msg']}');
        return false;
      }
      final d = res['data'] as Map<String, dynamic>;
      final sdkAppId = d['sdk_app_id'] as int;
      final userId = '${d['user_id']}';
      final userSig = d['user_sig'] as String;

      final handler = await TUICallKit.instance.login(sdkAppId, userId, userSig);
      if (!handler.isSuccess) {
        debugPrint('[CallService] TUICallKit.login failed: '
            'code=${handler.errorCode} msg=${handler.errorMessage}');
        return false;
      }
      _loggedIn = true;
      debugPrint('[CallService] TUICallKit login ok: user=$userId');

      if (nickname != null && nickname.isNotEmpty) {
        // 头像转绝对 URL（后端存的是相对路径，TUICallKit 需要完整 http(s)://… 才能加载），
        // /system/xxx 这种内置头像 TUICallKit 无法加载，一律传空让 SDK 用默认图
        final absAvatar = _normalizeAvatarForSdk(avatar ?? '');
        debugPrint('[CallService-diag] setSelfInfo: nick="$nickname" '
            'raw="$avatar" → abs="$absAvatar"');
        // 必须 await —— 否则 setSelfInfo 尚未同步到腾讯 IM，对方呼叫/接听时看不到昵称头像
        final r = await TUICallKit.instance.setSelfInfo(nickname, absAvatar);
        debugPrint('[CallService-diag] setSelfInfo result: success=${r.isSuccess} '
            'code=${r.errorCode} msg=${r.errorMessage}');
      }
      return true;
    } catch (e, st) {
      debugPrint('[CallService] login exception: $e\n$st');
      return false;
    }
  }

  /// 同步当前用户的昵称 / 头像到 TUICallKit（来电卡片与通话界面会显示）
  ///
  /// 参数 [avatar] 可以是相对路径（例如 `/uploads/avatar/xxx.jpg`）或完整 URL；
  /// 内部会自动补成绝对 URL 以保证 TUICallKit 能下载。
  Future<void> setSelfInfo({required String nickname, required String avatar}) async {
    if (!_loggedIn) return;
    try {
      final abs = _normalizeAvatarForSdk(avatar);
      await TUICallKit.instance.setSelfInfo(nickname, abs);
    } catch (e) {
      debugPrint('[CallService] setSelfInfo: $e');
    }
  }

  /// 把后端存的头像字段转成 TUICallKit 可加载的 URL：
  /// - 空串/null → 返回空（SDK 走默认头像）
  /// - `/system/…` 内置相对路径 → 返回空（TUICallKit 无法读取本地 assets）
  /// - 纯相对路径 → 拼上 API baseUrl
  /// - 已是 http(s)://… → 原样返回
  String _normalizeAvatarForSdk(String raw) {
    if (raw.isEmpty) return '';
    if (raw.startsWith('/system/')) {
      debugPrint('[CallService-diag] avatar is /system/* (internal asset, '
          'TUICallKit 无法加载本地 assets)，传空让 SDK 用默认图');
      return '';
    }
    final abs = UrlHelper.ensureAbsolute(raw);
    if (!abs.startsWith('http')) {
      debugPrint('[CallService-diag] avatar normalize failed: '
          'raw="$raw" → "$abs" (非 http(s) URL, 丢弃)');
      return '';
    }
    return abs;
  }

  Future<void> logout() async {
    if (!_loggedIn) {
      _loginFuture = null;
      return;
    }
    try {
      await TUICallKit.instance.logout();
    } catch (e) {
      debugPrint('[CallService] logout: $e');
    }
    _loggedIn = false;
    _loginFuture = null;
  }

  // ==========================================================================
  //  发起通话
  // ==========================================================================

  /// 预暖麦克风权限 —— 进入私聊页时可调一次，避免第一次 `calls()` 被系统权限弹窗阻塞
  /// （用户看起来像"点了没反应"）。
  Future<void> prewarmMicPermission() async {
    if (kIsWeb) return;
    final status = await Permission.microphone.status;
    if (status.isGranted) return;
    // 只在未授予状态下主动申请，已拒绝不重复骚扰
    if (status.isDenied) {
      await Permission.microphone.request();
    }
  }

  /// 发起 1v1 语音通话。UI 由 TUICallKit 自动弹出。
  ///
  /// 会先 `await loginReady`（最长 5s），保证长连接就绪；未登录则尝试重新登录。
  Future<bool> callVoice(int peerUserId) async {
    // 1) 等待登录就绪（防止首次点击时长连接未建立，TUICallKit 内部直接报错）
    final pending = _loginFuture;
    if (!_loggedIn && pending != null) {
      try {
        await pending.timeout(const Duration(seconds: 5));
      } on TimeoutException {
        debugPrint('[CallService] callVoice: login pending > 5s, proceed anyway');
      }
    }
    // 2) 若仍未登录，尝试即时登录一次（覆盖登录失败 / 未触发的边界）
    if (!_loggedIn) {
      final ok = await login();
      if (!ok) {
        debugPrint('[CallService] callVoice: login retry failed');
        return false;
      }
    }
    // 3) 真正发起呼叫
    try {
      final handler = await TUICallKit.instance.calls(
        [peerUserId.toString()],
        CallMediaType.audio,
        CallParams(),
      );
      if (!handler.isSuccess) {
        debugPrint('[CallService] calls failed: '
            'code=${handler.errorCode} msg=${handler.errorMessage}');
      }
      return handler.isSuccess;
    } catch (e) {
      debugPrint('[CallService] callVoice exception: $e');
      return false;
    }
  }
}
