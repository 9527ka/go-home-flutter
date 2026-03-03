import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
// HIDDEN_FEATURE: 好友 - 恢复时取消注释
// import '../../providers/friend_provider.dart';
import '../../widgets/delete_account_dialog.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final l = AppLocalizations.of(context)!;
    final notificationProvider = context.watch<NotificationProvider>();
    // HIDDEN_FEATURE: 好友 - 恢复时取消注释
    // final friendProvider = context.watch<FriendProvider>();

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: CustomScrollView(
        slivers: [
          // ===== 渐变色头部 =====
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                left: 24,
                right: 24,
                bottom: 28,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF5BA0E8), Color(0xFF4A90D9)],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  // 顶部导航栏
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          l.get('profile'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 36), // 占位对齐
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 头像 + 昵称（可点击编辑）
                  GestureDetector(
                    onTap: auth.isLoggedIn
                        ? () => Navigator.pushNamed(context, AppRoutes.editProfile)
                        : null,
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            _buildProfileAvatar(user),
                            if (auth.isLoggedIn)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(7),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
                                    ],
                                  ),
                                  child: const Icon(Icons.edit, size: 12, color: AppTheme.primaryColor),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // 昵称
                        Text(
                          user?.nickname ?? l.get('not_logged_in'),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 4),

                  // 账号
                  Text(
                    user?.account ?? '',
                    style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8)),
                  ),

                  // 用户 ID
                  if (user?.id != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'ID: ${user!.displayId}',
                        style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ===== 菜单区 =====
          SliverToBoxAdapter(child: SizedBox(height: 16)),

          // 功能菜单
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
                  _menuItem(
                    context,
                    icon: Icons.article_outlined,
                    iconColor: AppTheme.primaryColor,
                    title: l.get('my_posts'),
                    subtitle: l.get('my_posts_subtitle'),
                    onTap: () => Navigator.pushNamed(context, AppRoutes.myPosts),
                  ),
                  const Divider(indent: 58, height: 0.5),
                  _menuItem(
                    context,
                    icon: Icons.favorite_outline,
                    iconColor: AppTheme.dangerColor,
                    title: l.get('my_favorites'),
                    subtitle: l.get('my_favorites_subtitle'),
                    onTap: () => Navigator.pushNamed(context, AppRoutes.favorites),
                  ),
                  const Divider(indent: 58, height: 0.5),
                  _menuItem(
                    context,
                    icon: Icons.notifications_outlined,
                    iconColor: AppTheme.warningColor,
                    title: l.get('messages'),
                    subtitle: l.get('messages_subtitle'),
                    showBadge: notificationProvider.hasUnread,
                    onTap: () async {
                      await Navigator.pushNamed(context, AppRoutes.notifications);
                      // 从通知页返回后刷新未读数
                      notificationProvider.fetchUnreadCount();
                    },
                  ),
                  // HIDDEN_FEATURE: 好友 - "我的好友"菜单项，恢复时取消注释下方代码块
                  // const Divider(indent: 58, height: 0.5),
                  // _menuItem(
                  //   context,
                  //   icon: Icons.people_outline,
                  //   iconColor: const Color(0xFF06B6D4),
                  //   title: l.get('my_friends'),
                  //   subtitle: l.get('my_friends_subtitle'),
                  //   showBadge: friendProvider.hasNewRequests,
                  //   onTap: () async {
                  //     await Navigator.pushNamed(context, AppRoutes.friendListPage);
                  //     friendProvider.loadFriends();
                  //     friendProvider.fetchRequestCount();
                  //   },
                  // ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // 设置菜单
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
                    _menuItem(
                      context,
                      icon: Icons.manage_accounts_outlined,
                      iconColor: AppTheme.primaryColor,
                      title: l.get('account_settings'),
                      subtitle: l.get('account_settings_subtitle'),
                      onTap: () => Navigator.pushNamed(context, AppRoutes.accountSettings),
                    ),
                    const Divider(indent: 58, height: 0.5),
                  ],
                  _menuItem(
                    context,
                    icon: Icons.language,
                    iconColor: AppTheme.elderColor,
                    title: l.get('language_settings'),
                    subtitle: l.get('language_subtitle'),
                    onTap: () => Navigator.pushNamed(context, AppRoutes.language),
                  ),
                  const Divider(indent: 58, height: 0.5),
                  _menuItem(
                    context,
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
                  _menuItem(
                    context,
                    icon: Icons.info_outline,
                    iconColor: AppTheme.textSecondary,
                    title: l.get('about'),
                    subtitle: '${l.get('version')} 1.0.0',
                    onTap: () => Navigator.pushNamed(context, AppRoutes.about),
                  ),
                  if (auth.isLoggedIn) ...[
                    const Divider(indent: 58, height: 0.5),
                    _menuItem(
                      context,
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

          // 退出按钮
          if (auth.isLoggedIn)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () async {
                      // 退出确认
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
                        await auth.logout();
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
    );
  }

  /// 系统头像颜色和图标映射
  static const _systemAvatarStyles = <String, Map<String, dynamic>>{
    '/system/avatars/avatar_1.svg': {'color': Color(0xFF4A90D9), 'icon': Icons.person},
    '/system/avatars/avatar_2.svg': {'color': Color(0xFF5BA0E8), 'icon': Icons.person_outline},
    '/system/avatars/avatar_3.svg': {'color': Color(0xFF34A853), 'icon': Icons.face},
    '/system/avatars/avatar_4.svg': {'color': Color(0xFF8B5CF6), 'icon': Icons.sentiment_satisfied_alt},
    '/system/avatars/avatar_5.svg': {'color': Color(0xFFF97316), 'icon': Icons.emoji_people},
    '/system/avatars/avatar_6.svg': {'color': Color(0xFFEC4899), 'icon': Icons.face_3},
    '/system/avatars/avatar_7.svg': {'color': Color(0xFFF43F5E), 'icon': Icons.face_4},
    '/system/avatars/avatar_8.svg': {'color': Color(0xFFA855F7), 'icon': Icons.face_2},
    '/system/avatars/avatar_9.svg': {'color': Color(0xFF06B6D4), 'icon': Icons.face_5},
    '/system/avatars/avatar_10.svg': {'color': Color(0xFFEAB308), 'icon': Icons.face_6},
  };

  /// 用户头像 — 支持系统头像 / 网络图片 / 字母占位
  Widget _buildProfileAvatar(dynamic user) {
    final initial = user?.nickname?.isNotEmpty == true
        ? user!.nickname.substring(0, 1).toUpperCase()
        : '?';
    final avatarPath = user?.avatar ?? '';

    // 系统预设头像
    if (avatarPath.startsWith('/system/avatars/')) {
      final style = _systemAvatarStyles[avatarPath];
      final color = style?['color'] as Color? ?? AppTheme.primaryColor;
      final icon = style?['icon'] as IconData? ?? Icons.person;

      return Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Center(
          child: Icon(icon, size: 36, color: color),
        ),
      );
    }

    // 自定义网络头像
    if (avatarPath.isNotEmpty) {
      final avatarUrl = avatarPath;

      return Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Image.network(
            avatarUrl,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Center(
              child: Text(
                initial,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppTheme.primaryColor),
              ),
            ),
          ),
        ),
      );
    }

    // 默认字母占位
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppTheme.primaryColor),
        ),
      ),
    );
  }

  Widget _menuItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    bool showBadge = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
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
                if (showBadge)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.dangerColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
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
}
