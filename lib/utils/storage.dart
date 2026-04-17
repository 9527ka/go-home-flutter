import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageUtil {
  static const String _tokenKey = 'go_home_token';
  static const String _userInfoKey = 'go_home_user_info';
  static const String _languageKey = 'go_home_language';
  static const String _rememberMeKey = 'go_home_remember_me';

  // ---- Token ----

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // ---- 用户信息 ----

  static Future<void> saveUserInfo(Map<String, dynamic> userInfo) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userInfoKey, jsonEncode(userInfo));
  }

  static Future<Map<String, dynamic>?> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_userInfoKey);
    if (str != null && str.isNotEmpty) {
      return jsonDecode(str) as Map<String, dynamic>;
    }
    return null;
  }

  static Future<void> clearUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userInfoKey);
  }

  // ---- 语言 ----

  static Future<void> saveLanguage(String lang) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, lang);
  }

  static Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey) ?? 'zh-CN';
  }

  // ---- 记住我 ----

  static Future<void> saveRememberMe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberMeKey, value);
  }

  static Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rememberMeKey) ?? true;
  }

  // ---- 聊天最后已读消息 ID ----
  static const String _lastReadChatIdKey = 'go_home_last_read_chat_id';

  static Future<void> saveLastReadChatId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastReadChatIdKey, id);
  }

  static Future<int> getLastReadChatId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastReadChatIdKey) ?? 0;
  }

  // ---- EULA 用户协议同意状态 ----
  static const String _eulaAcceptedKey = 'go_home_eula_accepted';

  static Future<void> saveEulaAccepted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_eulaAcceptedKey, value);
  }

  static Future<bool> getEulaAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_eulaAcceptedKey) ?? false;
  }

  // ---- Posts Cache ----
  static const String _postsCacheKey = 'go_home_posts_cache';

  static Future<void> savePostsCache(String jsonStr) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_postsCacheKey, jsonStr);
  }

  static Future<String?> getPostsCache() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_postsCacheKey);
  }

  static Future<void> clearPostsCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_postsCacheKey);
  }

  // ---- Chat Messages Cache ----
  static const String _chatCacheKey = 'go_home_chat_cache';

  static Future<void> saveChatCache(String jsonStr) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chatCacheKey, jsonStr);
  }

  static Future<String?> getChatCache() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_chatCacheKey);
  }

  static Future<void> clearChatCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_chatCacheKey);
  }

  // ---- 是否已登录 ----

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// 一次性读取启动所需的认证状态（单次 getInstance，减少异步跳转）
  static Future<({bool rememberMe, bool isLoggedIn, Map<String, dynamic>? userInfo})> loadAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool(_rememberMeKey) ?? true;
    if (!rememberMe) {
      return (rememberMe: false, isLoggedIn: false, userInfo: null);
    }
    final token = prefs.getString(_tokenKey);
    final isLoggedIn = token != null && token.isNotEmpty;
    Map<String, dynamic>? userInfo;
    if (isLoggedIn) {
      final str = prefs.getString(_userInfoKey);
      if (str != null && str.isNotEmpty) {
        userInfo = jsonDecode(str) as Map<String, dynamic>;
      }
    }
    return (rememberMe: rememberMe, isLoggedIn: isLoggedIn, userInfo: userInfo);
  }
}
