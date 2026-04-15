import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/friend.dart';
import '../../models/group_member.dart';
import '../../providers/friend_provider.dart';
import '../../widgets/avatar_widget.dart';

/// 邀请好友入群页面
/// - 始终显示完整好友列表
/// - 已在群内的好友置灰、不可勾选、显示"已在群内"
/// - 支持按昵称 / 用户编号搜索
class GroupInviteMembersPage extends StatefulWidget {
  final Set<int> existingMemberIds;

  const GroupInviteMembersPage({super.key, required this.existingMemberIds});

  @override
  State<GroupInviteMembersPage> createState() => _GroupInviteMembersPageState();
}

class _GroupInviteMembersPageState extends State<GroupInviteMembersPage> {
  final _searchCtrl = TextEditingController();
  final Set<int> _selected = {};
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FriendProvider>().loadFriendsIfEmpty();
    });
    _searchCtrl.addListener(() {
      setState(() => _keyword = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matches(FriendModel f) {
    if (_keyword.isEmpty) return true;
    return f.displayName.toLowerCase().contains(_keyword) ||
        f.nickname.toLowerCase().contains(_keyword) ||
        f.userCode.toLowerCase().contains(_keyword) ||
        '${f.userId}'.contains(_keyword);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final friendProvider = context.watch<FriendProvider>();
    final allFriends = friendProvider.friends;
    final filtered = allFriends.where(_matches).toList();

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(l.get('invite_members')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _selected.isEmpty ? null : () => Navigator.pop(context, _selected),
            child: Text(
              _selected.isEmpty
                  ? l.get('confirm')
                  : l.get('selected_count').replaceAll('{count}', '${_selected.length}'),
              style: TextStyle(
                color: _selected.isEmpty ? AppTheme.textHint : AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: l.get('search_friends_hint'),
                prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textHint),
                suffixIcon: _keyword.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _searchCtrl.clear(),
                      ),
                filled: true,
                fillColor: AppTheme.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
            ),
          ),
          // 列表
          Expanded(
            child: friendProvider.isLoading && allFriends.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          allFriends.isEmpty ? l.get('no_friends') : l.get('no_matching_friends'),
                          style: const TextStyle(fontSize: 14, color: AppTheme.textHint),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) => _buildFriendItem(filtered[i], l),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendItem(FriendModel f, AppLocalizations l) {
    final inGroup = widget.existingMemberIds.contains(f.userId);
    final checked = _selected.contains(f.userId);
    final disabled = inGroup;

    return InkWell(
      onTap: disabled
          ? null
          : () {
              setState(() {
                if (checked) {
                  _selected.remove(f.userId);
                } else {
                  _selected.add(f.userId);
                }
              });
            },
      child: Opacity(
        opacity: disabled ? 0.5 : 1.0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // 勾选框
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: inGroup ? true : checked,
                  onChanged: disabled
                      ? null
                      : (v) {
                          setState(() {
                            if (v == true) {
                              _selected.add(f.userId);
                            } else {
                              _selected.remove(f.userId);
                            }
                          });
                        },
                  activeColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(width: 12),
              AvatarWidget(avatarPath: f.avatar, name: f.displayName, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.displayName,
                      style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (f.userCode.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'ID: ${f.userCode}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
                      ),
                    ],
                  ],
                ),
              ),
              if (inGroup)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.textHint.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    l.get('already_in_group'),
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 批量移出群成员页面
/// - 显示当前群所有成员（除自己）
/// - 多选后批量移出
/// - 权限：群主可移除所有人（除自己）；管理员仅可移除普通成员；普通成员不可进入此页
class GroupKickMembersPage extends StatefulWidget {
  final List<GroupMemberModel> members;
  final int currentUserId;
  final bool isOwner;

  const GroupKickMembersPage({
    super.key,
    required this.members,
    required this.currentUserId,
    required this.isOwner,
  });

  @override
  State<GroupKickMembersPage> createState() => _GroupKickMembersPageState();
}

class _GroupKickMembersPageState extends State<GroupKickMembersPage> {
  final _searchCtrl = TextEditingController();
  final Set<int> _selected = {};
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _keyword = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// 是否可被当前用户移除
  /// - 不能移除自己
  /// - 群主可移除所有人（除自己）
  /// - 管理员仅可移除普通成员
  bool _canKick(GroupMemberModel m) {
    if (m.userId == widget.currentUserId) return false;
    if (m.isOwner) return false;
    if (widget.isOwner) return true;
    return m.role == GroupMemberRole.member;
  }

  bool _matches(GroupMemberModel m) {
    if (_keyword.isEmpty) return true;
    return m.displayName.toLowerCase().contains(_keyword) ||
        m.userCode.toLowerCase().contains(_keyword) ||
        '${m.userId}'.contains(_keyword);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    // 过滤掉自己
    final candidates = widget.members.where((m) => m.userId != widget.currentUserId).toList();
    final filtered = candidates.where(_matches).toList();

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(l.get('kick_member')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: _selected.isEmpty ? null : () => Navigator.pop(context, _selected),
            child: Text(
              _selected.isEmpty
                  ? l.get('confirm')
                  : l.get('selected_count').replaceAll('{count}', '${_selected.length}'),
              style: TextStyle(
                color: _selected.isEmpty ? AppTheme.textHint : AppTheme.dangerColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: l.get('search_members_hint'),
                prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textHint),
                suffixIcon: _keyword.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _searchCtrl.clear(),
                      ),
                filled: true,
                fillColor: AppTheme.cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      l.get('no_matching_members'),
                      style: const TextStyle(fontSize: 14, color: AppTheme.textHint),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _buildMemberItem(filtered[i], l),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberItem(GroupMemberModel m, AppLocalizations l) {
    final canKick = _canKick(m);
    final checked = _selected.contains(m.userId);

    return InkWell(
      onTap: canKick
          ? () {
              setState(() {
                if (checked) {
                  _selected.remove(m.userId);
                } else {
                  _selected.add(m.userId);
                }
              });
            }
          : null,
      child: Opacity(
        opacity: canKick ? 1.0 : 0.5,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: checked,
                  onChanged: canKick
                      ? (v) {
                          setState(() {
                            if (v == true) {
                              _selected.add(m.userId);
                            } else {
                              _selected.remove(m.userId);
                            }
                          });
                        }
                      : null,
                  activeColor: AppTheme.dangerColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(width: 12),
              AvatarWidget(avatarPath: m.userAvatar, name: m.displayName, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.displayName,
                      style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (m.userCode.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('ID: ${m.userCode}', style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
                    ],
                  ],
                ),
              ),
              if (m.isOwner)
                _roleBadge(l.get('group_owner'), AppTheme.warningColor)
              else if (m.role == GroupMemberRole.admin)
                _roleBadge(l.get('group_admin'), AppTheme.primaryColor),
            ],
          ),
        ),
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
      child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }
}
