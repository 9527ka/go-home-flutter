import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/group.dart';
import '../../models/group_member.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';
import '../../services/group_service.dart';

class GroupDetailPage extends StatefulWidget {
  final int groupId;

  const GroupDetailPage({super.key, required this.groupId});

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  final GroupService _groupService = GroupService();

  GroupModel? _group;
  List<GroupMemberModel> _members = [];
  bool _isLoading = true;
  bool _isActioning = false;

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
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    try {
      final data = await _groupService.getGroupDetail(widget.groupId);
      if (data != null && mounted) {
        setState(() {
          _group = GroupModel.fromJson(data['group'] ?? data);
          final memberList = data['members'] as List? ?? [];
          _members = memberList
              .map((e) =>
                  GroupMemberModel.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('[GroupDetail] loadDetail error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int? get _currentUserId => context.read<AuthProvider>().user?.id;

  bool get _isOwner => _group != null && _group!.ownerId == _currentUserId;

  bool get _isAdmin {
    if (_isOwner) return true;
    final uid = _currentUserId;
    if (uid == null) return false;
    return _members.any((m) => m.userId == uid && m.isAdmin);
  }

  Future<void> _leaveGroup() async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.get('leave_group')),
        content: Text(l.get('leave_group_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.get('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerColor,
              foregroundColor: Colors.white,
            ),
            child: Text(l.get('confirm')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isActioning = true);
    final success =
        await context.read<GroupProvider>().leaveGroup(widget.groupId);

    if (!mounted) return;
    setState(() => _isActioning = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.get('group_left')),
          backgroundColor: AppTheme.successColor,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.get('network_error')),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
    }
  }

  Future<void> _disbandGroup() async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.get('disband_group')),
        content: Text(l.get('disband_group_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.get('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerColor,
              foregroundColor: Colors.white,
            ),
            child: Text(l.get('confirm')),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isActioning = true);
    final success =
        await context.read<GroupProvider>().disbandGroup(widget.groupId);

    if (!mounted) return;
    setState(() => _isActioning = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.get('group_disbanded')),
          backgroundColor: AppTheme.successColor,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.get('network_error')),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(_group?.name ?? l.get('group_info')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : _group == null
              ? Center(
                  child: Text(
                    l.get('network_error'),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textHint,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  children: [
                    // Group info card
                    _buildGroupInfoCard(l),

                    const SizedBox(height: 16),

                    // Member list section
                    _buildMemberSection(l),

                    const SizedBox(height: 24),

                    // Action buttons
                    _buildActionButtons(l),
                  ],
                ),
    );
  }

  Widget _buildGroupInfoCard(AppLocalizations l) {
    final group = _group!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          // Group avatar (large)
          _buildAvatar(group.avatar, group.name, size: 72),
          const SizedBox(height: 12),

          // Group name
          Text(
            group.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),

          // Group description
          if (group.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              group.description,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 12),

          // Member count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${l.get('group_members')} ${_members.length}',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberSection(AppLocalizations l) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l.get('group_members'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                // Invite button (owner/admin only)
                if (_isAdmin)
                  TextButton.icon(
                    onPressed: () {
                      // Placeholder for invite functionality
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l.get('coming_soon')),
                          backgroundColor: AppTheme.warningColor,
                        ),
                      );
                    },
                    icon: const Icon(Icons.person_add_outlined, size: 18),
                    label: Text(
                      l.get('invite_members'),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Member list
          ..._members.map((member) => _buildMemberItem(member, l)),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMemberItem(GroupMemberModel member, AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _buildAvatar(member.userAvatar, member.displayName, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              member.displayName,
              style: const TextStyle(
                fontSize: 15,
                color: AppTheme.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Role badge
          if (member.isOwner)
            _roleBadge(l.get('group_owner'), AppTheme.warningColor)
          else if (member.role == GroupMemberRole.admin)
            _roleBadge(l.get('group_admin'), AppTheme.primaryColor),
        ],
      ),
    );
  }

  Widget _roleBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildActionButtons(AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (_isOwner)
            // Disband group button (owner only)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isActioning ? null : _disbandGroup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.dangerColor,
                  foregroundColor: Colors.white,
                ),
                child: _isActioning
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        l.get('disband_group'),
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            )
          else
            // Leave group button (non-owner)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _isActioning ? null : _leaveGroup,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.dangerColor,
                  side: const BorderSide(color: AppTheme.dangerColor, width: 1.5),
                ),
                child: _isActioning
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.dangerColor,
                        ),
                      )
                    : Text(
                        l.get('leave_group'),
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ),
        ],
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
