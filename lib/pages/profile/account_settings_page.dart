import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/profile/change_account_dialog.dart';
import '../../widgets/profile/change_password_dialog.dart';
import '../../widgets/profile/profile_menu_item.dart';

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

    final isGuest = (user?.authProvider ?? 1) == 3;
    final isApple = (user?.authProvider ?? 1) == 2;
    final needOldPassword = !isGuest && !isApple;

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
            // Current account info card
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

            // Action menu
            Container(
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                children: [
                  ProfileMenuItem(
                    icon: Icons.email_outlined,
                    iconColor: AppTheme.primaryColor,
                    title: isGuest || isApple
                        ? l.get('bind_account')
                        : l.get('change_account'),
                    subtitle: isGuest || isApple
                        ? l.get('bind_account_subtitle')
                        : l.get('change_account_subtitle'),
                    onTap: () => ChangeAccountDialog.show(
                      context,
                      onSuccess: () => setState(() {}),
                    ),
                  ),
                  const Divider(indent: 58, height: 0.5),
                  ProfileMenuItem(
                    icon: Icons.lock_outline,
                    iconColor: AppTheme.elderColor,
                    title: (isGuest || isApple)
                        ? l.get('set_password')
                        : l.get('change_password'),
                    subtitle: (isGuest || isApple)
                        ? l.get('set_password_subtitle')
                        : l.get('change_password_subtitle'),
                    onTap: () => ChangePasswordDialog.show(
                      context,
                      needOldPassword: needOldPassword,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
