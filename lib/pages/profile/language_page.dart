import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/locale_provider.dart';
import 'package:provider/provider.dart';

class LanguagePage extends StatelessWidget {
  const LanguagePage({super.key});

  static const _languages = [
    _LanguageOption(locale: Locale('zh', 'CN'), name: '简体中文', nameEn: 'Simplified Chinese'),
    _LanguageOption(locale: Locale('zh', 'TW'), name: '繁體中文', nameEn: 'Traditional Chinese'),
    _LanguageOption(locale: Locale('en', 'US'), name: 'English', nameEn: 'English'),
  ];

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    final currentLocale = localeProvider.locale;
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(l.get('language_settings')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // 提示文字
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Text(
              l.get('select_language'),
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ),

          // 语言列表
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              children: _languages.asMap().entries.map((entry) {
                final index = entry.key;
                final lang = entry.value;
                final isSelected = currentLocale.languageCode == lang.locale.languageCode &&
                    currentLocale.countryCode == lang.locale.countryCode;

                return Column(
                  children: [
                    if (index > 0) const Divider(indent: 58, height: 0.5),
                    _buildLanguageItem(
                      context,
                      lang: lang,
                      isSelected: isSelected,
                      onTap: () {
                        localeProvider.setLocale(lang.locale);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${l.get('switched_to')}${lang.name}'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 20),

          // 说明
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              l.get('language_switch_hint'),
              style: const TextStyle(fontSize: 12, color: AppTheme.textHint, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageItem(
    BuildContext context, {
    required _LanguageOption lang,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // 语言图标
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor.withOpacity(0.1)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  _getFlag(lang.locale),
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),

            const SizedBox(width: 14),

            // 语言名称
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    lang.nameEn,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
                  ),
                ],
              ),
            ),

            // 选中标记
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 16, color: Colors.white),
              )
            else
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.dividerColor, width: 1.5),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getFlag(Locale locale) {
    switch ('${locale.languageCode}_${locale.countryCode}') {
      case 'zh_CN': return '🇨🇳';
      case 'zh_TW': return '🇹🇼';
      case 'en_US': return '🇺🇸';
      default: return '🌐';
    }
  }
}

class _LanguageOption {
  final Locale locale;
  final String name;
  final String nameEn;

  const _LanguageOption({
    required this.locale,
    required this.name,
    required this.nameEn,
  });
}
