import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final l = AppLocalizations.of(context)!;

    // 判断是否为游客/Apple用户
    final isGuest = (user?.authProvider ?? 1) == 3;
    final isApple = (user?.authProvider ?? 1) == 2;
    final hasRealAccount = !isGuest && !isApple && (user?.account.isNotEmpty ?? false);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(l.get('account_settings')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 当前账号信息卡片
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isGuest ? Icons.person_outline : Icons.verified_user_outlined,
                          color: AppTheme.primaryColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.get('current_account'),
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textHint,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isGuest
                                  ? l.get('guest_account')
                                  : isApple
                                      ? 'Apple ID'
                                      : (user?.account ?? ''),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isGuest)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.warningColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            l.get('guest_tag'),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.warningColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (isGuest) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: AppTheme.warningColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l.get('guest_bind_hint'),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.warningColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 操作菜单
            Container(
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                children: [
                  // 修改账号
                  _menuItem(
                    icon: Icons.email_outlined,
                    iconColor: AppTheme.primaryColor,
                    title: isGuest || isApple
                        ? l.get('bind_account')
                        : l.get('change_account'),
                    subtitle: isGuest || isApple
                        ? l.get('bind_account_subtitle')
                        : l.get('change_account_subtitle'),
                    onTap: () => _showChangeAccountDialog(context),
                  ),
                  const Divider(indent: 58, height: 0.5),
                  // 修改密码
                  _menuItem(
                    icon: Icons.lock_outline,
                    iconColor: AppTheme.elderColor,
                    title: (isGuest || isApple)
                        ? l.get('set_password')
                        : l.get('change_password'),
                    subtitle: (isGuest || isApple)
                        ? l.get('set_password_subtitle')
                        : l.get('change_password_subtitle'),
                    onTap: () => _showChangePasswordDialog(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
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
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                  if (subtitle != null)
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textHint, size: 20),
          ],
        ),
      ),
    );
  }

  /// 修改账号弹窗
  void _showChangeAccountDialog(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final accountCtrl = TextEditingController();
    int accountType = 1; // 1=手机号 2=邮箱

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final auth = context.read<AuthProvider>();

          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 拖拽条
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  l.get('change_account'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),

                // 账号类型切换
                Row(
                  children: [
                    _typeChip(
                      label: l.get('phone'),
                      selected: accountType == 1,
                      onTap: () => setModalState(() => accountType = 1),
                    ),
                    const SizedBox(width: 12),
                    _typeChip(
                      label: l.get('email'),
                      selected: accountType == 2,
                      onTap: () => setModalState(() => accountType = 2),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 输入框
                TextField(
                  controller: accountCtrl,
                  keyboardType: accountType == 1
                      ? TextInputType.phone
                      : TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: accountType == 1
                        ? l.get('phone_hint')
                        : l.get('email_hint'),
                    prefixIcon: Icon(
                      accountType == 1 ? Icons.phone_outlined : Icons.email_outlined,
                      size: 20,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 保存按钮
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: auth.isLoading
                        ? null
                        : () async {
                            final account = accountCtrl.text.trim();
                            if (account.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l.get('account_empty')),
                                  backgroundColor: AppTheme.dangerColor,
                                ),
                              );
                              return;
                            }

                            final error = await auth.changeAccount(account, accountType);
                            if (!context.mounted) return;

                            if (error == null) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l.get('account_change_success')),
                                  backgroundColor: AppTheme.successColor,
                                ),
                              );
                              setState(() {}); // 刷新页面
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(error),
                                  backgroundColor: AppTheme.dangerColor,
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: auth.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Text(l.get('save'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _typeChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : AppTheme.dividerColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  /// 修改密码弹窗
  void _showChangePasswordDialog(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    final isGuest = (user?.authProvider ?? 1) == 3;
    final isApple = (user?.authProvider ?? 1) == 2;
    final needOldPassword = !isGuest && !isApple;

    final oldPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 拖拽条
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  needOldPassword ? l.get('change_password') : l.get('set_password'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),

                // 旧密码（仅普通用户）
                if (needOldPassword) ...[
                  TextField(
                    controller: oldPasswordCtrl,
                    obscureText: obscureOld,
                    decoration: InputDecoration(
                      hintText: l.get('old_password_hint'),
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureOld ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20,
                          color: AppTheme.textHint,
                        ),
                        onPressed: () => setModalState(() => obscureOld = !obscureOld),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // 新密码
                TextField(
                  controller: newPasswordCtrl,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    hintText: l.get('new_password_hint'),
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20,
                        color: AppTheme.textHint,
                      ),
                      onPressed: () => setModalState(() => obscureNew = !obscureNew),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // 确认新密码
                TextField(
                  controller: confirmPasswordCtrl,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    hintText: l.get('confirm_new_password_hint'),
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20,
                        color: AppTheme.textHint,
                      ),
                      onPressed: () => setModalState(() => obscureConfirm = !obscureConfirm),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 保存按钮
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: auth.isLoading
                        ? null
                        : () async {
                            final newPwd = newPasswordCtrl.text;
                            final confirmPwd = confirmPasswordCtrl.text;

                            if (newPwd.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l.get('password_empty')),
                                  backgroundColor: AppTheme.dangerColor,
                                ),
                              );
                              return;
                            }
                            if (newPwd.length < 6) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l.get('password_too_short')),
                                  backgroundColor: AppTheme.dangerColor,
                                ),
                              );
                              return;
                            }
                            if (newPwd != confirmPwd) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l.get('password_mismatch')),
                                  backgroundColor: AppTheme.dangerColor,
                                ),
                              );
                              return;
                            }

                            final error = await auth.changePassword(
                              oldPassword: needOldPassword ? oldPasswordCtrl.text : null,
                              newPassword: newPwd,
                            );

                            if (!context.mounted) return;

                            if (error == null) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l.get('password_change_success')),
                                  backgroundColor: AppTheme.successColor,
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(error),
                                  backgroundColor: AppTheme.dangerColor,
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: auth.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Text(l.get('save'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
