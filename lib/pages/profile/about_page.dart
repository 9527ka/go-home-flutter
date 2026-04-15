import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../providers/app_config_provider.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final about = context.watch<AppConfigProvider>().about;
    final version = about['version'] ?? 'v1.0.0';
    final telegram = about['telegram'] ?? '';
    final websiteUrl = about['website_url'] ?? '';
    final websiteName = about['website_name'] ?? '';
    final mission = about['mission'] ?? '';
    final safety = about['safety'] ?? '';
    final freeService = about['free_service'] ?? '';
    final disclaimer = about['disclaimer'] ?? '';
    final privacy = about['privacy'] ?? '';

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('关于我们'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 40),

            // ===== App 图标 + 名称 =====
            _buildAppInfo(),

            const SizedBox(height: 36),

            // ===== 平台介绍 =====
            if (mission.isNotEmpty || safety.isNotEmpty || freeService.isNotEmpty)
              _buildSection(
                context,
                children: [
                  if (mission.isNotEmpty)
                    _buildDescRow(
                      icon: Icons.favorite_outline,
                      iconColor: AppTheme.dangerColor,
                      title: '平台宗旨',
                      desc: mission,
                    ),
                  if (mission.isNotEmpty && safety.isNotEmpty)
                    const Divider(indent: 52, height: 0.5),
                  if (safety.isNotEmpty)
                    _buildDescRow(
                      icon: Icons.shield_outlined,
                      iconColor: AppTheme.primaryColor,
                      title: '安全保障',
                      desc: safety,
                    ),
                  if (safety.isNotEmpty && freeService.isNotEmpty)
                    const Divider(indent: 52, height: 0.5),
                  if (freeService.isNotEmpty)
                    _buildDescRow(
                      icon: Icons.volunteer_activism_outlined,
                      iconColor: AppTheme.accentColor,
                      title: '公益免费',
                      desc: freeService,
                    ),
                ],
              ),

            if (mission.isNotEmpty || safety.isNotEmpty || freeService.isNotEmpty)
              const SizedBox(height: 12),

            // ===== 联系方式 =====
            if (telegram.isNotEmpty || websiteUrl.isNotEmpty)
              _buildSection(
                context,
                children: [
                  if (telegram.isNotEmpty)
                    _buildInfoRow(
                      icon: Icons.send_rounded,
                      iconColor: const Color(0xFF0088CC),
                      title: 'Telegram',
                      value: telegram,
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: telegram));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已复制到剪贴板'), duration: Duration(seconds: 1)),
                        );
                      },
                    ),
                  if (telegram.isNotEmpty && websiteUrl.isNotEmpty)
                    const Divider(indent: 52, height: 0.5),
                  if (websiteUrl.isNotEmpty)
                    _buildLinkRow(
                      icon: Icons.language,
                      iconColor: AppTheme.successColor,
                      title: '官方网站',
                      subtitle: websiteName.isNotEmpty ? websiteName : websiteUrl,
                      onTap: () => _openUrl(websiteUrl),
                    ),
                ],
              ),

            if (telegram.isNotEmpty || websiteUrl.isNotEmpty)
              const SizedBox(height: 12),

            // ===== 法律声明 =====
            if (disclaimer.isNotEmpty || privacy.isNotEmpty)
              _buildSection(
                context,
                children: [
                  if (disclaimer.isNotEmpty)
                    _buildDescRow(
                      icon: Icons.gavel_outlined,
                      iconColor: AppTheme.textSecondary,
                      title: '免责声明',
                      desc: disclaimer,
                    ),
                  if (disclaimer.isNotEmpty && privacy.isNotEmpty)
                    const Divider(indent: 52, height: 0.5),
                  if (privacy.isNotEmpty)
                    _buildDescRow(
                      icon: Icons.privacy_tip_outlined,
                      iconColor: AppTheme.textSecondary,
                      title: '隐私政策',
                      desc: privacy,
                    ),
                ],
              ),

            const SizedBox(height: 32),

            // ===== 底部版权 =====
            Text(
              version,
              style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
            ),
            const SizedBox(height: 6),
            Text(
              '© ${DateTime.now().year} 回家了么 All Rights Reserved',
              style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
            ),
            const SizedBox(height: 8),
            const Text(
              'Made with ❤️ for those who are lost',
              style: TextStyle(fontSize: 11, color: AppTheme.textHint),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAppInfo() {
    return Column(
      children: [
        // App 图标
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset('assets/icon/app_icon.png', width: 80, height: 80),
          ),
        ),

        const SizedBox(height: 16),

        const Text(
          '回家了么',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),

        const SizedBox(height: 4),

        const Text(
          '帮助每一个走失的生命回家',
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSection(BuildContext context, {required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary)),
            const Spacer(),
            Text(value, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.copy, size: 14, color: AppTheme.textHint),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildLinkRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: iconColor)),
                ],
              ),
            ),
            Icon(Icons.open_in_new, size: 16, color: iconColor.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }

  Widget _buildDescRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String desc,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                Text(desc, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
