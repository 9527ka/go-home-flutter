import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart';
import '../l10n/app_localizations.dart';
import 'eula_dialog.dart';

/// 首次启动隐私协议弹窗 — Apple 审核 Guideline 5.1.1
/// 用户必须同意后才能使用 App
class PrivacyConsentDialog extends StatelessWidget {
  const PrivacyConsentDialog({super.key});

  static const String _prefKey = 'privacy_agreed';

  /// 检查用户是否已同意
  static Future<bool> hasAgreed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  /// 保存同意状态
  static Future<void> _saveAgreed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }

  /// 弹出隐私弹窗，返回用户是否同意
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PrivacyConsentDialog(),
    );
    if (result == true) {
      await _saveAgreed();
    }
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            Text(
              l.get('privacy_dialog_title'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 20),

            // 内容
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bullet(l.get('privacy_dialog_point_1')),
                    const SizedBox(height: 10),
                    _bullet(l.get('privacy_dialog_point_2')),
                    const SizedBox(height: 10),
                    _bullet(l.get('privacy_dialog_point_3')),
                    const SizedBox(height: 10),
                    _bullet(l.get('privacy_dialog_point_4')),
                    const SizedBox(height: 16),

                    // 协议链接
                    _buildLinks(context, l),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 按钮
            Row(
              children: [
                // 不同意
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: const BorderSide(color: AppTheme.dividerColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(l.get('privacy_dialog_disagree')),
                  ),
                ),
                const SizedBox(width: 12),
                // 同意
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      l.get('privacy_dialog_agree'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 7),
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: AppTheme.textHint,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLinks(BuildContext context, AppLocalizations l) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13, color: AppTheme.textHint, height: 1.5),
        children: [
          TextSpan(text: l.get('privacy_dialog_link_prefix')),
          TextSpan(
            text: l.get('privacy_dialog_terms_link'),
            style: const TextStyle(color: AppTheme.primaryColor),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _showTerms(context),
          ),
          TextSpan(text: l.get('privacy_dialog_link_and')),
          TextSpan(
            text: l.get('privacy_dialog_privacy_link'),
            style: const TextStyle(color: AppTheme.primaryColor),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _showPrivacy(context),
          ),
        ],
      ),
    );
  }

  /// 点击《服务协议》— 复用 EULA 弹窗
  void _showTerms(BuildContext context) {
    EulaDialog.show(context);
  }

  /// 点击《隐私政策》— 显示隐私政策部分
  void _showPrivacy(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.shield_outlined, color: AppTheme.primaryColor, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l.get('eula_section_5'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              l.get('eula_content_5'),
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.6,
              ),
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(l.get('close')),
          ),
        ],
      ),
    );
  }
}
