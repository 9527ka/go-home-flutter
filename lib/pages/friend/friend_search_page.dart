import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/user.dart';
import '../../providers/friend_provider.dart';

class FriendSearchPage extends StatefulWidget {
  const FriendSearchPage({super.key});

  @override
  State<FriendSearchPage> createState() => _FriendSearchPageState();
}

class _FriendSearchPageState extends State<FriendSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<UserModel> _results = [];
  bool _isSearching = false;
  bool _hasSearched = false;

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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _doSearch() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    final results = await context.read<FriendProvider>().searchUsers(keyword);

    if (mounted) {
      setState(() {
        _results = results;
        _isSearching = false;
      });
    }
  }

  Future<void> _sendRequest(UserModel user) async {
    final l = AppLocalizations.of(context)!;
    final messageController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l.get('send_request')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              user.nickname,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: messageController,
              decoration: InputDecoration(
                hintText: l.get('request_message_hint'),
                hintStyle: const TextStyle(fontSize: 14, color: AppTheme.textHint),
              ),
              maxLines: 2,
              maxLength: 50,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.get('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.get('confirm')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      messageController.dispose();
      return;
    }

    final message = messageController.text.trim();
    messageController.dispose();

    final friendProvider = context.read<FriendProvider>();
    final error = await friendProvider.sendRequest(
          toId: user.id,
          message: message,
        );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error != null ? l.get(error) : l.get('request_sent')),
        duration: const Duration(seconds: 2),
      ),
    );

    // 刷新好友列表，更新搜索结果中的 "已是好友" 状态
    if (error == null) {
      friendProvider.loadFriends();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final friendProvider = context.watch<FriendProvider>();

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(l.get('add_friend')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: l.get('search_by_phone_or_id'),
                      prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textHint),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _doSearch(),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSearching ? null : _doSearch,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(72, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(l.get('search')),
                  ),
                ),
              ],
            ),
          ),

          // Results area
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : !_hasSearched
                    ? _buildInitialState(l)
                    : _results.isEmpty
                        ? _buildNoResults(l)
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _results.length,
                            itemBuilder: (_, index) =>
                                _buildUserItem(_results[index], friendProvider, l),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserItem(UserModel user, FriendProvider friendProvider, AppLocalizations l) {
    final isFriend = friendProvider.isFriend(user.id);

    return Container(
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
            _buildAvatar(user.avatar, user.nickname, 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.nickname,
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
                    'ID: ${user.displayId}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isFriend)
              Text(
                l.get('already_friends'),
                style: const TextStyle(fontSize: 13, color: AppTheme.textHint),
              )
            else
              OutlinedButton(
                onPressed: () => _sendRequest(user),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor, width: 1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  minimumSize: Size.zero,
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                child: Text(l.get('add_friend')),
              ),
          ],
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

  Widget _buildInitialState(AppLocalizations l) {
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
              Icons.person_search_outlined,
              size: 40,
              color: AppTheme.primaryColor.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l.get('search_user'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l.get('search_by_phone_or_id'),
            style: const TextStyle(fontSize: 13, color: AppTheme.textHint),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults(AppLocalizations l) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.search_off,
              size: 40,
              color: AppTheme.warningColor.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l.get('no_results'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l.get('search_by_phone_or_id'),
            style: const TextStyle(fontSize: 13, color: AppTheme.textHint),
          ),
        ],
      ),
    );
  }
}
