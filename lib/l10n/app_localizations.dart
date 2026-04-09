import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'localizations_zh_cn.dart';
import 'localizations_zh_tw.dart';
import 'localizations_en_us.dart';

/// 多语言支持
/// MVP 阶段先用简单的 Map 方式，后续迁移到 flutter_intl / arb
class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const localizationsDelegates = [
    _AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static const supportedLocales = [
    Locale('zh', 'CN'),
    Locale('zh', 'TW'),
    Locale('en', 'US'),
  ];

  // ---- 翻译数据 ----
  static final Map<String, Map<String, String>> _translations = {
    'zh_CN': zhCnTranslations,
    'zh_TW': zhTwTranslations,
    'en_US': enUsTranslations,
  };

  String get(String key) {
    final langKey = '${locale.languageCode}_${locale.countryCode}';
    return _translations[langKey]?[key] ?? _translations['en_US']?[key] ?? key;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['zh', 'en'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate old) => true;
}
