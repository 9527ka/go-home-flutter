import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../l10n/app_localizations.dart';

/// EULA 用户协议详情弹窗 — Apple 审核要求 Guideline 1.2
/// 纯展示协议内容，点击关闭即可
class EulaDialog extends StatelessWidget {
  const EulaDialog({super.key});

  /// 弹出协议详情
  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const EulaDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.gavel_rounded, color: AppTheme.primaryColor, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l.get('eula_title'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.5,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(l.get('eula_section_1')),
              _paragraph(l.get('eula_content_1')),
              _sectionTitle(l.get('eula_section_2')),
              _paragraph(l.get('eula_content_2')),
              _sectionTitle(l.get('eula_section_3')),
              _paragraph(l.get('eula_content_3')),
              _sectionTitle(l.get('eula_section_4')),
              _paragraph(l.get('eula_content_4')),
              _sectionTitle(l.get('eula_section_5')),
              _paragraph(l.get('eula_content_5')),
              _sectionTitle(l.get('eula_section_6')),
              _paragraph(l.get('eula_content_6')),
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(l.get('close')),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _paragraph(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        color: AppTheme.textSecondary,
        height: 1.6,
      ),
    );
  }
}
