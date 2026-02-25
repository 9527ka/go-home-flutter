import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
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

            // ===== 功能介绍 =====
            _buildSection(
              context,
              children: [
                _buildInfoRow(
                  icon: Icons.info_outline,
                  iconColor: AppTheme.primaryColor,
                  title: '版本号',
                  value: '1.0.0',
                ),
                const Divider(indent: 52, height: 0.5),
                _buildInfoRow(
                  icon: Icons.update,
                  iconColor: AppTheme.successColor,
                  title: '构建版本',
                  value: 'Build 1',
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ===== 平台介绍 =====
            _buildSection(
              context,
              children: [
                _buildDescRow(
                  icon: Icons.favorite_outline,
                  iconColor: AppTheme.dangerColor,
                  title: '平台宗旨',
                  desc: '帮助每一个走失的生命找到回家的路。通过公众力量汇聚爱心线索，为走失成年人、儿童、宠物提供免费的信息发布与传播平台。',
                ),
                const Divider(indent: 52, height: 0.5),
                _buildDescRow(
                  icon: Icons.shield_outlined,
                  iconColor: AppTheme.primaryColor,
                  title: '安全保障',
                  desc: '所有信息经过人工审核，儿童类信息隐藏精确地址。举报功能保障信息质量，保护用户隐私安全。',
                ),
                const Divider(indent: 52, height: 0.5),
                _buildDescRow(
                  icon: Icons.volunteer_activism_outlined,
                  iconColor: AppTheme.accentColor,
                  title: '公益免费',
                  desc: '平台所有功能完全免费。发布启事、提供线索、分享传播，所有操作均不收取任何费用。',
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ===== 联系方式 =====
            _buildSection(
              context,
              children: [
                _buildInfoRow(
                  icon: Icons.email_outlined,
                  iconColor: AppTheme.elderColor,
                  title: '联系邮箱',
                  value: 'support@gohome.com',
                  onTap: () {
                    Clipboard.setData(const ClipboardData(text: 'support@gohome.com'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('邮箱已复制到剪贴板'), duration: Duration(seconds: 1)),
                    );
                  },
                ),
                const Divider(indent: 52, height: 0.5),
                _buildInfoRow(
                  icon: Icons.language,
                  iconColor: AppTheme.successColor,
                  title: '官方网站',
                  value: 'www.gohome.com',
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ===== 法律声明 =====
            _buildSection(
              context,
              children: [
                _buildDescRow(
                  icon: Icons.gavel_outlined,
                  iconColor: AppTheme.textSecondary,
                  title: '免责声明',
                  desc: '本平台仅提供信息发布与传播服务，不保证信息的真实性与准确性。如遇紧急情况请立即拨打110报警电话。发布虚假信息将被永久封禁。',
                ),
                const Divider(indent: 52, height: 0.5),
                _buildDescRow(
                  icon: Icons.privacy_tip_outlined,
                  iconColor: AppTheme.textSecondary,
                  title: '隐私政策',
                  desc: '我们重视用户隐私保护。个人信息仅用于平台服务，不会泄露给第三方。儿童类启事的详细地址将自动隐藏。',
                ),
              ],
            ),

            const SizedBox(height: 32),

            // ===== 底部版权 =====
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
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF5BA0E8), Color(0xFF4A90D9)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              '🏠',
              style: TextStyle(fontSize: 36),
            ),
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
