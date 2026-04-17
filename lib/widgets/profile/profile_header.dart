import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/sign_provider.dart';
import '../../utils/url_helper.dart';

/// Gradient header section with avatar, user info, and sign-in button.
class ProfileHeader extends StatelessWidget {
  final dynamic user;
  final bool isLoggedIn;
  final bool walletEnabled;
  final VoidCallback? onQrTap;

  const ProfileHeader({
    super.key,
    required this.user,
    required this.isLoggedIn,
    required this.walletEnabled,
    this.onQrTap,
  });

  /// System avatar color and icon mapping.
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Container(
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
          // 导航栏：返回 + 标题 + 扫一扫
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
              if (onQrTap != null)
                GestureDetector(
                  onTap: onQrTap,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.qr_code, size: 18, color: Colors.white),
                  ),
                )
              else
                const SizedBox(width: 36),
            ],
          ),
          const SizedBox(height: 20),

          // Avatar row: avatar + user info + sign-in button
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar (tappable to edit)
              GestureDetector(
                onTap: isLoggedIn
                    ? () => Navigator.pushNamed(context, AppRoutes.editProfile)
                    : null,
                child: Stack(
                  children: [
                    _buildProfileAvatar(user),
                    if (isLoggedIn)
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
              ),

              const SizedBox(width: 16),

              // Nickname + account + ID
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.nickname ?? l.get('not_logged_in'),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (user?.account != null && user!.account.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          user.account,
                          style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.8)),
                        ),
                      ),
                    if (user?.id != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'ID: ${user!.displayId}',
                          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6)),
                        ),
                      ),
                  ],
                ),
              ),

              // Sign-in button
              if (isLoggedIn && walletEnabled)
                _buildSignInButton(context),
            ],
          ),
        ],
      ),
    );
  }

  /// User avatar - supports system avatar / network image / letter placeholder.
  Widget _buildProfileAvatar(dynamic user) {
    final initial = user?.nickname?.isNotEmpty == true
        ? user!.nickname.substring(0, 1).toUpperCase()
        : '?';
    final avatarPath = user?.avatar ?? '';

    // System preset avatar
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

    // Custom network avatar
    if (avatarPath.isNotEmpty) {
      final avatarUrl = UrlHelper.ensureAbsolute(avatarPath);

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

    // Default letter placeholder
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

  /// Sign-in button (beside the avatar).
  Widget _buildSignInButton(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final signProvider = context.watch<SignProvider>();
    final signedToday = signProvider.signedToday;
    final streak = signProvider.currentStreak;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.signIn),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: signedToday ? Colors.white.withOpacity(0.2) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: signedToday
              ? null
              : [BoxShadow(color: Colors.white.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              signedToday ? Icons.check_circle : Icons.calendar_today,
              size: 22,
              color: signedToday ? Colors.white.withOpacity(0.9) : AppTheme.primaryColor,
            ),
            const SizedBox(height: 4),
            Text(
              signedToday ? l.get('signed_btn') : l.get('sign_btn'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: signedToday ? Colors.white.withOpacity(0.9) : AppTheme.primaryColor,
              ),
            ),
            if (streak > 0)
              Text(
                l.get('streak_short').replaceAll('{n}', '$streak'),
                style: TextStyle(
                  fontSize: 9,
                  color: signedToday ? Colors.white.withOpacity(0.7) : AppTheme.textHint,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
