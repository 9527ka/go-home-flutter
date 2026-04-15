import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/friend.dart';
import '../../providers/friend_provider.dart';
import '../../providers/group_provider.dart';

class GroupCreatePage extends StatefulWidget {
  const GroupCreatePage({super.key});

  @override
  State<GroupCreatePage> createState() => _GroupCreatePageState();
}

class _GroupCreatePageState extends State<GroupCreatePage> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final Set<int> _selectedIds = {};
  bool _isCreating = false;

  /// System avatar style map
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FriendProvider>().loadFriendsIfEmpty();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool get _canCreate =>
      _nameCtrl.text.trim().isNotEmpty &&
      _selectedIds.isNotEmpty &&
      !_isCreating;

  Future<void> _createGroup() async {
    if (!_canCreate) return;

    setState(() => _isCreating = true);

    try {
      final group = await context.read<GroupProvider>().createGroup(
            name: _nameCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            memberIds: _selectedIds.toList(),
          );

      if (!mounted) return;

      final l = AppLocalizations.of(context)!;
      if (group != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.get('group_created')),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.pop(context, group);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.get('network_error')),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.get('network_error')),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final friendProvider = context.watch<FriendProvider>();
    final friends = friendProvider.friends;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(l.get('create_group')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                // Group name
                Text(
                  l.get('group_name'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtrl,
                  maxLength: 50,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: l.get('group_name_hint'),
                    counterText: '',
                  ),
                ),

                const SizedBox(height: 20),

                // Group description
                Text(
                  l.get('group_description'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descCtrl,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: l.get('group_description_hint'),
                    counterText: '',
                  ),
                ),

                const SizedBox(height: 24),

                // Select members header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l.get('select_members'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      l.get('selected_count').replaceAll(
                            '{count}',
                            '${_selectedIds.length}',
                          ),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Friend list
                if (friendProvider.isLoading && friends.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  )
                else if (friends.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        l.get('no_friends'),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textHint,
                        ),
                      ),
                    ),
                  )
                else
                  ...friends.map((friend) => _buildFriendItem(friend)),
              ],
            ),
          ),

          // Bottom create button
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _canCreate ? _createGroup : null,
                child: _isCreating
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        l.get('create'),
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendItem(FriendModel friend) {
    final isSelected = _selectedIds.contains(friend.userId);
    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedIds.remove(friend.userId);
          } else {
            _selectedIds.add(friend.userId);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppTheme.dividerColor, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Checkbox
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: isSelected,
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selectedIds.add(friend.userId);
                    } else {
                      _selectedIds.remove(friend.userId);
                    }
                  });
                },
                activeColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Avatar
            _buildAvatar(friend.avatar, friend.displayName, size: 36),
            const SizedBox(width: 12),

            // Display name
            Expanded(
              child: Text(
                friend.displayName,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppTheme.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String avatarUrl, String name, {double size = 36}) {
    final initial =
        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';

    // System preset avatar
    if (avatarUrl.startsWith('/system/avatars/')) {
      final style = _sysAvatarMap[avatarUrl];
      if (style != null) {
        final color = style[0] as Color;
        final icon = style[1] as IconData;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(size * 0.28),
          ),
          child: Center(
            child: Icon(icon, size: size * 0.55, color: color),
          ),
        );
      }
    }

    // Network image
    if (avatarUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: Image.network(
          avatarUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _avatarPlaceholder(initial, size),
        ),
      );
    }

    // Fallback: first letter
    return _avatarPlaceholder(initial, size);
  }

  Widget _avatarPlaceholder(String initial, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(size * 0.28),
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
