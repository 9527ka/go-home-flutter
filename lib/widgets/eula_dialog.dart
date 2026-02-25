import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../l10n/app_localizations.dart';
import '../utils/storage.dart';

/// EULA 用户协议弹窗 — Apple 审核要求 Guideline 1.2
/// 用户必须同意后才能使用应用
class EulaDialog extends StatelessWidget {
  const EulaDialog({super.key});

  /// 检查并展示 EULA（如果用户未同意过）
  /// 返回 true = 已同意，false = 拒绝
  static Future<bool> checkAndShow(BuildContext context) async {
    final accepted = await StorageUtil.getEulaAccepted();
    if (accepted) return true;

    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const EulaDialog(),
    );

    if (result == true) {
      await StorageUtil.saveEulaAccepted(true);
      return true;
    }
    return false;
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
        height: 400,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('一、服务条款'),
              _paragraph(
                '欢迎使用「回家了么」。本应用是一个公益性质的走失信息发布平台，'
                '旨在帮助走失人员和宠物找到回家的路。使用本应用即表示您同意以下条款。',
              ),
              _sectionTitle('二、用户行为规范'),
              _paragraph(
                '1. 您不得发布任何虚假、误导性的走失信息。\n'
                '2. 您不得发布任何淫秽、色情、暴力、恐怖、歧视性或其他违反法律法规的内容。\n'
                '3. 您不得利用本平台进行欺诈、诈骗或其他非法活动。\n'
                '4. 您不得骚扰、辱骂、威胁其他用户。\n'
                '5. 您不得发布广告、垃圾信息或与平台用途无关的内容。',
              ),
              _sectionTitle('三、对不当内容零容忍'),
              _paragraph(
                '本平台对不当内容和违规行为采取零容忍政策：\n\n'
                '• 任何违反上述规范的内容将被立即删除。\n'
                '• 发布违规内容的用户将被永久封禁。\n'
                '• 我们将在收到举报后24小时内处理。\n'
                '• 严重违规行为将向相关执法部门举报。',
              ),
              _sectionTitle('四、内容审核与举报'),
              _paragraph(
                '• 所有发布的内容需经审核后展示。\n'
                '• 您可以举报任何不当内容或用户。\n'
                '• 您可以屏蔽任何您不希望看到的用户。\n'
                '• 我们的团队将及时审核举报并采取行动。',
              ),
              _sectionTitle('五、隐私政策'),
              _paragraph(
                '• 我们仅收集提供服务所必需的最少信息。\n'
                '• 用户信息仅用于平台服务，不会向第三方出售或共享。\n'
                '• 为保护儿童安全，儿童类启事的精确地址将被隐藏。\n'
                '• 您可以随时注销账号并删除所有个人数据。',
              ),
              _sectionTitle('六、免责声明'),
              _paragraph(
                '• 本平台不保证所发布信息的真实性和准确性。\n'
                '• 如遇紧急情况，请立即拨打110报警。\n'
                '• 发布虚假信息造成的一切后果由发布者承担。',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context, false);
            // 提示用户必须同意
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l.get('eula_decline_hint')),
                backgroundColor: AppTheme.warningColor,
              ),
            );
          },
          child: Text(
            l.get('eula_decline'),
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(l.get('eula_agree')),
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
