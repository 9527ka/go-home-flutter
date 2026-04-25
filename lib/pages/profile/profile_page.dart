import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';

import '../../providers/app_config_provider.dart';
import '../../providers/sign_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../utils/session_reset.dart';
import '../../widgets/delete_account_dialog.dart';
import '../../widgets/profile/profile_header.dart';
import '../../widgets/profile/profile_menu_item.dart';
import '../../widgets/profile/wallet_card.dart';
import 'cache_management_page.dart';
import 'my_qr_code_page.dart';
import 'scan_qr_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.isLoggedIn) {
        final appConfig = context.read<AppConfigProvider>();
        if (appConfig.walletEnabled) {
          context.read<WalletProvider>().loadWalletInfo();
          context.read<SignProvider>().loadStatus();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final l = AppLocalizations.of(context)!;
    final notificationProvider = context.watch<NotificationProvider>();
    final appConfig = context.watch<AppConfigProvider>();

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: RefreshIndicator(
        onRefresh: () async {
          final auth = context.read<AuthProvider>();
          if (auth.isLoggedIn) {
            final appConfig = context.read<AppConfigProvider>();
            if (appConfig.walletEnabled) {
              await context.read<WalletProvider>().loadWalletInfo();
              await context.read<SignProvider>().loadStatus();
            }
            await context.read<NotificationProvider>().fetchUnreadCount();
          }
        },
        child: CustomScrollView(
        slivers: [
          // ===== Gradient header =====
          SliverToBoxAdapter(
            child: ProfileHeader(
              user: user,
              isLoggedIn: auth.isLoggedIn,
              walletEnabled: appConfig.walletEnabled,
              onQrTap: auth.isLoggedIn
                  ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyQrCodePage()))
                  : null,
            ),
          ),

          // ===== Menu area =====
          SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Wallet card (prominent, at the top)
          if (appConfig.walletEnabled && auth.isLoggedIn)
            const SliverToBoxAdapter(
              child: WalletCard(),
            ),

          if (appConfig.walletEnabled && auth.isLoggedIn)
            const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // Feature menu
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                children: [
                  ProfileMenuItem(
                    icon: Icons.article_outlined,
                    iconColor: AppTheme.primaryColor,
                    title: l.get('my_posts'),
                    subtitle: l.get('my_posts_subtitle'),
                    onTap: () => Navigator.pushNamed(context, AppRoutes.myPosts),
                  ),
                  const Divider(indent: 58, height: 0.5),
                  if (auth.isLoggedIn) ...[
                    ProfileMenuItem(
                      icon: Icons.workspace_premium_outlined,
                      iconColor: AppTheme.warningColor,
                      title: 'VIP 中心',
                      subtitle: '开通 / 续费 / 专属特效',
                      onTap: () => Navigator.pushNamed(context, AppRoutes.vipCenter),
                    ),
                    const Divider(indent: 58, height: 0.5),
                  ],
                  ProfileMenuItem(
                    icon: Icons.favorite_outline,
                    iconColor: AppTheme.dangerColor,
                    title: l.get('my_favorites'),
                    subtitle: l.get('my_favorites_subtitle'),
                    onTap: () => Navigator.pushNamed(context, AppRoutes.favorites),
                  ),
                  const Divider(indent: 58, height: 0.5),
                  ProfileMenuItem(
                    icon: Icons.notifications_outlined,
                    iconColor: AppTheme.warningColor,
                    title: l.get('messages'),
                    subtitle: l.get('messages_subtitle'),
                    showBadge: notificationProvider.hasUnread,
                    onTap: () async {
                      await Navigator.pushNamed(context, AppRoutes.notifications);
                      notificationProvider.fetchUnreadCount();
                    },
                  ),
                  // "我的好友"已隐藏
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // Settings menu
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                children: [
                  if (auth.isLoggedIn) ...[
                    ProfileMenuItem(
                      icon: Icons.manage_accounts_outlined,
                      iconColor: AppTheme.primaryColor,
                      title: l.get('account_settings'),
                      subtitle: l.get('account_settings_subtitle'),
                      onTap: () => Navigator.pushNamed(context, AppRoutes.accountSettings),
                    ),
                    const Divider(indent: 58, height: 0.5),
                    ProfileMenuItem(
                      icon: Icons.storage_outlined,
                      iconColor: AppTheme.warningColor,
                      title: l.get('cache_management'),
                      subtitle: l.get('cache_management_subtitle'),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CacheManagementPage())),
                    ),
                    const Divider(indent: 58, height: 0.5),
                  ],
                  ProfileMenuItem(
                    icon: Icons.language,
                    iconColor: AppTheme.elderColor,
                    title: l.get('language_settings'),
                    subtitle: l.get('language_subtitle'),
                    onTap: () => Navigator.pushNamed(context, AppRoutes.language),
                  ),
                  const Divider(indent: 58, height: 0.5),
                  ProfileMenuItem(
                    icon: Icons.feedback_outlined,
                    iconColor: AppTheme.successColor,
                    title: l.get('feedback'),
                    subtitle: l.get('feedback_subtitle'),
                    onTap: () {
                      if (auth.isLoggedIn) {
                        Navigator.pushNamed(context, AppRoutes.feedback);
                      } else {
                        Navigator.pushNamed(context, AppRoutes.login);
                      }
                    },
                  ),
                  const Divider(indent: 58, height: 0.5),
                  ProfileMenuItem(
                    icon: Icons.info_outline,
                    iconColor: AppTheme.textSecondary,
                    title: l.get('about'),
                    subtitle: appConfig.about['version'] ?? '${l.get('version')} 1.0.0',
                    onTap: () => Navigator.pushNamed(context, AppRoutes.about),
                  ),
                  if (auth.isLoggedIn) ...[
                    const Divider(indent: 58, height: 0.5),
                    ProfileMenuItem(
                      icon: Icons.person_off_outlined,
                      iconColor: AppTheme.dangerColor,
                      title: l.get('delete_account'),
                      subtitle: l.get('delete_account_subtitle'),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => const DeleteAccountDialog(),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Logout button
          if (auth.isLoggedIn)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: Text(l.get('confirm_logout')),
                          content: Text(l.get('logout_hint')),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.get('cancel'))),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(l.get('logout'), style: const TextStyle(color: AppTheme.dangerColor)),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && context.mounted) {
                        // 彻底清理 Provider 内存 + per-user prefs，防止新账号登录后看到上一个账号的数据
                        await performLogout(context);
                        if (context.mounted) {
                          Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (route) => false);
                        }
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.dangerColor,
                      side: const BorderSide(color: AppTheme.dangerColor, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(l.get('logout'), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
      ),
    );
  }
}
