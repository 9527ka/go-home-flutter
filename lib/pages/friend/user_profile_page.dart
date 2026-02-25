import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/chat_provider.dart';
import '../../providers/friend_provider.dart';

/// User profile bottom sheet displayed when tapping a user's avatar in chat.
class UserProfilePage extends StatefulWidget {
  final int userId;
  final String nickname;
  final String avatar;

  const UserProfilePage({
    super.key,
    required this.userId,
    required this.nickname,
    required this.avatar,
  });

  /// Show the user profile bottom sheet.
  static void show(
    BuildContext context, {
    required int userId,
    required String nickname,
    required String avatar,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: AppTheme.cardBg,
      builder: (_) => UserProfilePage(
        userId: userId,
        nickname: nickname,
        avatar: avatar,
      ),
    );
  }

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  bool _isSendingRequest = false;
  bool _isBlocking = false;

  /// System avatar color and icon mapping
  static const _sysAvatarMap = <String, List<dynamic>>{
    '/system/avatars/avatar_1.svg': [Color(0xFF4A90D9), Icons.person],
    '/system/avatars/avatar_2.svg': [Color(0xFF5BA0E8), Icons.person_outline],
    '/system/avatars/avatar_3.svg': [Color(0xFF34A853), Icons.face],
    '/system/avatars/avatar_4.svg': [
      Color(0xFF8B5CF6),
      Icons.sentiment_satisfied_alt
    ],
    '/system/avatars/avatar_5.svg': [Color(0xFFF97316), Icons.emoji_people],
    '/system/avatars/avatar_6.svg': [Color(0xFFEC4899), Icons.face_3],
    '/system/avatars/avatar_7.svg': [Color(0xFFF43F5E), Icons.face_4],
    '/system/avatars/avatar_8.svg': [Color(0xFFA855F7), Icons.face_2],
    '/system/avatars/avatar_9.svg': [Color(0xFF06B6D4), Icons.face_5],
    '/system/avatars/avatar_10.svg': [Color(0xFFEAB308), Icons.face_6],
  };

  Future<void> _handleAddFriend() async {
    setState(() => _isSendingRequest = true);

    final error = await context.read<FriendProvider>().sendRequest(
          toId: widget.userId,
        );

    if (!mounted) return;
    setState(() => _isSendingRequest = false);

    final l = AppLocalizations.of(context)!;
    Fluttertoast.showToast(msg: error ?? l.get('request_sent'));
  }

  Future<void> _handleToggleBlock() async {
    final chatProvider = context.read<ChatProvider>();
    final isBlocked = chatProvider.isUserBlocked(widget.userId);

    setState(() => _isBlocking = true);

    if (isBlocked) {
      await chatProvider.unblockUser(widget.userId);
    } else {
      await chatProvider.blockUser(widget.userId);
    }

    if (!mounted) return;
    setState(() => _isBlocking = false);
  }

  void _handleSendMessage() {
    final l = AppLocalizations.of(context)!;
    Fluttertoast.showToast(msg: l.get('coming_soon'));
  }

  void _handleReport() {
    final l = AppLocalizations.of(context)!;
    Fluttertoast.showToast(msg: l.get('coming_soon'));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final friendProvider = context.watch<FriendProvider>();
    final chatProvider = context.watch<ChatProvider>();
    final isFriend = friendProvider.isFriend(widget.userId);
    final isBlocked = chatProvider.isUserBlocked(widget.userId);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              l.get('user_profile'),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 24),

            // Avatar
            _buildAvatar(widget.avatar, widget.nickname, 72),
            const SizedBox(height: 16),

            // Nickname
            Text(
              widget.nickname,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),

            // User ID
            Text(
              'ID: ${widget.userId}',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textHint,
              ),
            ),
            const SizedBox(height: 28),

            // Action buttons
            Row(
              children: [
                // Send Message / Add Friend
                Expanded(
                  child: isFriend
                      ? _buildActionButton(
                          label: l.get('send_message'),
                          icon: Icons.chat_bubble_outline_rounded,
                          color: AppTheme.primaryColor,
                          isLoading: false,
                          onPressed: _handleSendMessage,
                        )
                      : _buildActionButton(
                          label: l.get('add_friend'),
                          icon: Icons.person_add_outlined,
                          color: AppTheme.primaryColor,
                          isLoading: _isSendingRequest,
                          onPressed: _isSendingRequest
                              ? null
                              : _handleAddFriend,
                        ),
                ),
                const SizedBox(width: 10),

                // Block / Unblock
                Expanded(
                  child: _buildActionButton(
                    label: isBlocked
                        ? l.get('unblock_user')
                        : l.get('block_user'),
                    icon: isBlocked
                        ? Icons.visibility_rounded
                        : Icons.block_rounded,
                    color: isBlocked
                        ? AppTheme.successColor
                        : AppTheme.dangerColor,
                    isLoading: _isBlocking,
                    onPressed: _isBlocking ? null : _handleToggleBlock,
                  ),
                ),
                const SizedBox(width: 10),

                // Report
                Expanded(
                  child: _buildActionButton(
                    label: l.get('report'),
                    icon: Icons.flag_outlined,
                    color: AppTheme.warningColor,
                    isLoading: false,
                    onPressed: _handleReport,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isLoading,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildAvatar(String avatarPath, String name, double size) {
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
    final radius = size * 0.28;

    // System preset avatar
    if (avatarPath.startsWith('/system/avatars/')) {
      final style = _sysAvatarMap[avatarPath];
      if (style != null) {
        final color = style[0] as Color;
        final icon = style[1] as IconData;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Center(
            child: Icon(icon, size: size * 0.55, color: color),
          ),
        );
      }
    }

    // Network image avatar
    if (avatarPath.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          avatarPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _buildLetterAvatar(initial, size, radius),
        ),
      );
    }

    // Default letter placeholder
    return _buildLetterAvatar(initial, size, radius);
  }

  Widget _buildLetterAvatar(String initial, double size, double radius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.39,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }
}
