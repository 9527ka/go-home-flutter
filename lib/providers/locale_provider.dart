import 'package:flutter/material.dart';
import '../utils/storage.dart';

/// 语言切换状态管理
class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en', 'US');

  Locale get locale => _locale;

  /// 初始化：从本地存储读取语言设置
  Future<void> init() async {
    final langStr = await StorageUtil.getLanguage();
    _locale = _parseLocale(langStr);
    notifyListeners();
  }

  /// 切换语言
  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    final langStr = '${locale.languageCode}-${locale.countryCode}';
    await StorageUtil.saveLanguage(langStr);
    notifyListeners();
  }

  /// 解析语言字符串为 Locale
  Locale _parseLocale(String langStr) {
    // 支持 "zh-CN"、"zh_CN" 两种格式
    final parts = langStr.replaceAll('_', '-').split('-');
    if (parts.length >= 2) {
      return Locale(parts[0], parts[1]);
    }
    return Locale(parts[0]);
  }
}
