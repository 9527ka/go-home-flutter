import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/friend.dart';
import '../../providers/friend_provider.dart';

class FriendListPage extends StatefulWidget {
  const FriendListPage({super.key});

  @override
  State<FriendListPage> createState() => _FriendListPageState();
}

class _FriendListPageState extends State<FriendListPage> {
  /// System avatar color and icon mapping
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
  void initState() {
    super.initState();
    final friendProvider = context.read<FriendProvider>();
    friendProvider.loadFriends();
    friendProvider.fetchRequestCount();
  }

  Future<void> _removeFriend(FriendModel friend) async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l.get('remove_friend')),
        content: Text(l.get('remove_friend_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.get('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l.get('confirm'),
              style: const TextStyle(color: AppTheme.dangerColor),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final error = await context.read<FriendProvider>().removeFriend(friend.userId);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? l.get('friend_removed')),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final friendProvider = context.watch<FriendProvider>();
    final friends = friendProvider.friends;
    final hasNewRequests = friendProvider.hasNewRequests;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(l.get('my_friends')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.person_add_outlined, size: 22),
                onPressed: () => Navigator.pushNamed(context, AppRoutes.friendRequests),
              ),
              if (hasNewRequests)
                Positioned(
                  right: 8,
                  top: 8,
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
        ],
      ),
      body: friendProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : friends.isEmpty
              ? _buildEmpty(l)
              : RefreshIndicator(
                  onRefresh: () async {
                    await friendProvider.loadFriends();
                    await friendProvider.fetchRequestCount();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: friends.length,
                    itemBuilder: (_, index) => _buildFriendItem(friends[index], l),
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.friendSearch),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.search, color: Colors.white),
      ),
    );
  }

  Widget _buildFriendItem(FriendModel friend, AppLocalizations l) {
    return Dismissible(
      key: ValueKey(friend.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.dangerColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_remove, color: AppTheme.dangerColor, size: 22),
            const SizedBox(height: 4),
            Text(
              l.get('remove_friend'),
              style: const TextStyle(fontSize: 11, color: AppTheme.dangerColor),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        await _removeFriend(friend);
        return false;
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _buildAvatar(friend.avatar, friend.displayName, 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend.displayName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      friend.account,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.textHint, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String avatarPath, String name, double size) {
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
    final radius = size / 2;

    // System preset avatar
    if (avatarPath.startsWith('/system/avatars/')) {
      final style = _systemAvatarStyles[avatarPath];
      final color = style?['color'] as Color? ?? AppTheme.primaryColor;
      final icon = style?['icon'] as IconData? ?? Icons.person;

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

    // Network image avatar
    if (avatarPath.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          avatarPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildLetterAvatar(initial, size, radius),
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
            fontSize: size * 0.45,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(AppLocalizations l) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.people_outline,
              size: 40,
              color: AppTheme.primaryColor.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l.get('no_friends'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l.get('my_friends_subtitle'),
            style: const TextStyle(fontSize: 13, color: AppTheme.textHint),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.friendSearch),
            icon: const Icon(Icons.person_add_outlined, size: 18),
            label: Text(l.get('add_friend')),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: const BorderSide(color: AppTheme.primaryColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}
