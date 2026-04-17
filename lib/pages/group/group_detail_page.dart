import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/group.dart';
import '../../models/group_member.dart';
import '../../providers/auth_provider.dart';
import '../../providers/conversation_provider.dart';
import '../../providers/group_provider.dart';
import '../../services/group_service.dart';
import '../../services/upload_service.dart';
import '../../widgets/avatar_widget.dart';
import '../friend/user_profile_page.dart';
import 'group_chat_page.dart';
import 'group_member_selector_pages.dart';
import 'group_qr_dialog.dart';

/// 群聊详情页 — 布局与公共聊天室保持一致，额外提供群管理功能
class GroupDetailPage extends StatefulWidget {
  final int groupId;

  const GroupDetailPage({super.key, required this.groupId});

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  final GroupService _groupService = GroupService();
  final UploadService _uploadService = UploadService();
  final ImagePicker _imagePicker = ImagePicker();

  GroupModel? _group;
  List<GroupMemberModel> _members = [];
  bool _isLoading = true;
  bool _isActioning = false;
  bool _isUploadingAvatar = false;
  bool _showAllMembers = false;

  bool _muteNotifications = false;
  bool _pinChat = false;

  static const _membersPerRow = 5;
  static const _maxRows = 3;

  @override
  void initState() {
    super.initState();
    _loadDetail();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _muteNotifications = prefs.getBool('conv_mute_group_${widget.groupId}') ?? false;
        // 公共聊天室（id=1）强制置顶，不读取本地开关
        _pinChat = widget.groupId == 1
            ? true
            : (prefs.getBool('conv_pin_group_${widget.groupId}') ?? false);
      });
    }
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
              .map((e) => GroupMemberModel.fromJson(e as Map<String, dynamic>))
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

  // ===== 设置开关 =====

  Future<void> _toggleMute(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('conv_mute_group_${widget.groupId}', value);
    if (mounted) setState(() => _muteNotifications = value);
    // 同步到服务端
    try {
      await context.read<ConversationProvider>().setConversationMuted(
            widget.groupId,
            'group',
            value,
          );
    } catch (_) {}
  }

  Future<void> _togglePin(bool value) async {
    // 公共聊天室（id=1）强制置顶，禁止取消
    if (widget.groupId == 1) {
      final l = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.get('public_room_always_pinned'))),
      );
      setState(() => _pinChat = true);
      return;
    }
    // 通过 Provider 持久化并触发会话列表重排
    await context
        .read<ConversationProvider>()
        .setPinned(widget.groupId, 'group', value);
    if (mounted) setState(() => _pinChat = value);
  }

  // ===== 编辑群信息 =====

  Future<void> _editField(String key, String currentValue, String title, {int maxLines = 1, int maxLength = 100}) async {
    final l = AppLocalizations.of(context)!;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _EditFieldDialog(
        title: title,
        initialValue: currentValue,
        maxLines: maxLines,
        maxLength: maxLength,
        cancelText: l.get('cancel'),
        confirmText: l.get('confirm'),
        // 群公告内容较长，弹窗占屏幕 95% 宽度；其他字段保持默认窄弹窗
        widthFactor: key == 'announcement' ? 0.95 : null,
      ),
    );
    if (result == null || result == currentValue || !mounted) return;

    final success = await _groupService.updateGroup(
      groupId: widget.groupId,
      name: key == 'name' && result.isNotEmpty ? result : null,
      description: key == 'description' ? result : null,
      announcement: key == 'announcement' ? result : null,
    );
    if (!mounted) return;
    if (success) {
      // 乐观更新本地 _group，立即反映到 UI；随后 await 服务端刷新作为兜底
      final g = _group;
      if (g != null) {
        setState(() {
          _group = GroupModel(
            id: g.id,
            name: key == 'name' ? result : g.name,
            avatar: g.avatar,
            description: key == 'description' ? result : g.description,
            announcement: key == 'announcement' ? result : g.announcement,
            ownerId: g.ownerId,
            maxMembers: g.maxMembers,
            memberCount: g.memberCount,
            status: g.status,
            banned: g.banned,
            allMuted: g.allMuted,
            createdAt: g.createdAt,
          );
        });
      }
      await _loadDetail();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.get('network_error')), backgroundColor: AppTheme.dangerColor),
      );
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final l = AppLocalizations.of(context)!;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 4, decoration: BoxDecoration(color: AppTheme.dividerColor, borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.primaryColor),
              title: Text(l.get('take_photo')),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppTheme.primaryColor),
              title: Text(l.get('choose_from_album')),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final picked = await _imagePicker.pickImage(source: source, maxWidth: 800, maxHeight: 800, imageQuality: 85);
    if (picked == null || !mounted) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressQuality: 85,
      maxWidth: 512,
      maxHeight: 512,
      uiSettings: [
        AndroidUiSettings(toolbarTitle: l.get('crop_avatar'), lockAspectRatio: true),
        IOSUiSettings(title: l.get('crop_avatar'), aspectRatioLockEnabled: true),
      ],
    );
    if (cropped == null || !mounted) return;

    setState(() => _isUploadingAvatar = true);
    try {
      final url = await _uploadService.uploadXFile(XFile(cropped.path));
      if (url != null && mounted) {
        final success = await _groupService.updateGroup(groupId: widget.groupId, avatar: url);
        if (success && mounted) _loadDetail();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.get('network_error')), backgroundColor: AppTheme.dangerColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  // ===== 成员管理 =====

  Future<void> _inviteMembers() async {
    final l = AppLocalizations.of(context)!;
    final existingIds = _members.map((m) => m.userId).toSet();

    final result = await Navigator.push<Set<int>>(
      context,
      MaterialPageRoute(
        builder: (_) => GroupInviteMembersPage(existingMemberIds: existingIds),
      ),
    );

    if (result == null || result.isEmpty || !mounted) return;
    final success = await _groupService.inviteMembers(widget.groupId, result.toList());
    if (!mounted) return;
    if (success) {
      _loadDetail();
      _syncMemberAvatars();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.get('network_error')), backgroundColor: AppTheme.dangerColor),
      );
    }
  }

  Future<void> _batchKickMembers() async {
    if (!_isAdmin) return;
    final l = AppLocalizations.of(context)!;
    final currentUid = _currentUserId;
    if (currentUid == null) return;

    final selected = await Navigator.push<Set<int>>(
      context,
      MaterialPageRoute(
        builder: (_) => GroupKickMembersPage(
          members: _members,
          currentUserId: currentUid,
          isOwner: _isOwner,
        ),
      ),
    );

    if (selected == null || selected.isEmpty || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.get('kick_member')),
        content: Text(l.get('batch_kick_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.get('cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerColor, foregroundColor: Colors.white),
            child: Text(l.get('confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    int successCount = 0;
    int failCount = 0;
    for (final uid in selected) {
      try {
        final ok = await _groupService.kickMember(widget.groupId, uid);
        if (ok) {
          successCount++;
        } else {
          failCount++;
        }
      } catch (_) {
        failCount++;
      }
    }
    if (!mounted) return;

    if (successCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.get('members_kicked').replaceAll('{n}', '$successCount')),
          backgroundColor: AppTheme.successColor,
        ),
      );
      _loadDetail();
      _syncMemberAvatars();
    }
    if (failCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.get('kick_partial_failed').replaceAll('{n}', '$failCount')),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
    }
  }

  Future<void> _toggleAdmin(GroupMemberModel member) async {
    final l = AppLocalizations.of(context)!;
    final newRole = member.role == GroupMemberRole.admin ? 0 : 1;
    final success = await _groupService.setMemberRole(widget.groupId, member.userId, newRole);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.get('role_updated')), backgroundColor: AppTheme.successColor),
        );
        _loadDetail();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.get('network_error')), backgroundColor: AppTheme.dangerColor),
        );
      }
    }
  }

  Future<void> _kickSingleMember(GroupMemberModel member) async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.get('kick_member')),
        content: Text(l.get('kick_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.get('cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerColor, foregroundColor: Colors.white),
            child: Text(l.get('confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final success = await _groupService.kickMember(widget.groupId, member.userId);
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.get('member_kicked')), backgroundColor: AppTheme.successColor),
      );
      _loadDetail();
      _syncMemberAvatars();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.get('network_error')), backgroundColor: AppTheme.dangerColor),
      );
    }
  }

  void _syncMemberAvatars() {
    final avatars = _members.map((m) => m.userAvatar).take(9).toList();
    final names = _members.map((m) => m.displayName).take(9).toList();
    context.read<ConversationProvider>().setGroupMemberAvatars(widget.groupId, avatars, names);
  }

  // ===== 成员点击菜单（长按 / 点击） =====

  void _showMemberActions(GroupMemberModel member) {
    if (!_isAdmin) {
      _openMemberProfile(member);
      return;
    }
    if (member.userId == _currentUserId) return;

    final l = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 4, decoration: BoxDecoration(color: AppTheme.dividerColor, borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: const Icon(Icons.person_outline, color: AppTheme.primaryColor),
              title: Text(l.get('view_profile')),
              onTap: () {
                Navigator.pop(ctx);
                _openMemberProfile(member);
              },
            ),
            if (_isOwner && !member.isOwner)
              ListTile(
                leading: Icon(
                  member.role == GroupMemberRole.admin ? Icons.remove_moderator_outlined : Icons.admin_panel_settings_outlined,
                  color: AppTheme.primaryColor,
                ),
                title: Text(member.role == GroupMemberRole.admin ? l.get('remove_admin') : l.get('set_admin')),
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleAdmin(member);
                },
              ),
            if ((_isOwner && !member.isOwner) ||
                (_isAdmin && member.role == GroupMemberRole.member))
              ListTile(
                leading: const Icon(Icons.volume_off_outlined, color: AppTheme.warningColor),
                title: Text(
                  member.isMuted ? l.get('group_unmute_member') : l.get('group_mute_member'),
                  style: const TextStyle(color: AppTheme.warningColor),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  if (member.isMuted) {
                    _muteMember(member, 0);
                  } else {
                    _showMuteDurationPicker(member);
                  }
                },
              ),
            if ((_isOwner && !member.isOwner) ||
                (_isAdmin && member.role == GroupMemberRole.member))
              ListTile(
                leading: const Icon(Icons.person_remove_outlined, color: AppTheme.dangerColor),
                title: Text(l.get('kick_member'), style: const TextStyle(color: AppTheme.dangerColor)),
                onTap: () {
                  Navigator.pop(ctx);
                  _kickSingleMember(member);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 弹出禁言时长选择
  Future<void> _showMuteDurationPicker(GroupMemberModel member) async {
    final l = AppLocalizations.of(context)!;
    final options = <_MuteOption>[
      _MuteOption(10, l.get('mute_10min')),
      _MuteOption(60, l.get('mute_1hour')),
      _MuteOption(60 * 24, l.get('mute_1day')),
      _MuteOption(-1, l.get('mute_forever')),
    ];

    final picked = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 4, decoration: BoxDecoration(color: AppTheme.dividerColor, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l.get('group_mute_duration_title').replaceAll('{name}', member.alias.isNotEmpty ? member.alias : member.userNickname),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
            for (final opt in options)
              ListTile(
                leading: const Icon(Icons.volume_off_outlined, color: AppTheme.warningColor),
                title: Text(opt.label),
                onTap: () => Navigator.pop(ctx, opt.minutes),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    await _muteMember(member, picked);
  }

  Future<void> _toggleAllMuted(bool value) async {
    final l = AppLocalizations.of(context)!;
    if (_group == null) return;
    final ok = await _groupService.setAllMuted(widget.groupId, value);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _group = _group!.copyWith(allMuted: value ? 1 : 0);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? l.get('group_all_mute_on_success') : l.get('group_all_mute_off_success')),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.get('network_error')), backgroundColor: AppTheme.dangerColor),
      );
    }
  }

  Future<void> _muteMember(GroupMemberModel member, int minutes) async {
    final l = AppLocalizations.of(context)!;
    final ok = await _groupService.muteMember(
      groupId: widget.groupId,
      userId: member.userId,
      minutes: minutes,
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(minutes == 0 ? l.get('group_unmute_success') : l.get('group_mute_success')),
          backgroundColor: AppTheme.successColor,
        ),
      );
      _loadDetail();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.get('network_error')), backgroundColor: AppTheme.dangerColor),
      );
    }
  }

  void _openMemberProfile(GroupMemberModel member) {
    if (member.userId == _currentUserId) return;
    UserProfilePage.show(
      context,
      userId: member.userId,
      nickname: member.userNickname,
      avatar: member.userAvatar,
      userCode: member.userCode,
    );
  }

  // ===== 退出 / 解散 =====

  Future<void> _leaveGroup() async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.get('leave_group')),
        content: Text(l.get('leave_group_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.get('cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerColor, foregroundColor: Colors.white),
            child: Text(l.get('confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isActioning = true);
    final success = await context.read<GroupProvider>().leaveGroup(widget.groupId);
    if (!mounted) return;
    setState(() => _isActioning = false);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.get('group_left')), backgroundColor: AppTheme.successColor),
      );
      context.read<ConversationProvider>().removeConversation(widget.groupId, 'group');
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.get('network_error')), backgroundColor: AppTheme.dangerColor),
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.get('cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerColor, foregroundColor: Colors.white),
            child: Text(l.get('confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isActioning = true);
    final success = await context.read<GroupProvider>().disbandGroup(widget.groupId);
    if (!mounted) return;
    setState(() => _isActioning = false);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.get('group_disbanded')), backgroundColor: AppTheme.successColor),
      );
      context.read<ConversationProvider>().removeConversation(widget.groupId, 'group');
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.get('network_error')), backgroundColor: AppTheme.dangerColor),
      );
    }
  }

  // ===== 清空聊天记录 =====

  Future<void> _handleClearChat() async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.get('clear_chat_history')),
        content: Text(l.get('clear_chat_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.get('cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerColor, foregroundColor: Colors.white),
            child: Text(l.get('confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // 本地记录"清空时间"，群聊页加载历史时会过滤掉此时间之前的消息
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('group_cleared_at_${widget.groupId}', DateTime.now().millisecondsSinceEpoch);

    // 清除进程内缓存，避免缓存里的旧消息在下次进入群聊时复现
    GroupChatPage.invalidateCache(widget.groupId);

    // 清除会话列表中的最后消息预览
    if (!mounted) return;
    context.read<ConversationProvider>().onMessageSent(
          targetId: widget.groupId,
          targetType: 'group',
          content: '',
          name: _group?.name ?? '',
          avatar: _group?.avatar ?? '',
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.get('chat_history_cleared')), backgroundColor: AppTheme.successColor),
    );
  }

  // ===== UI =====

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(l.get('group_info')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _group == null
              ? Center(
                  child: Text(
                    l.get('network_error'),
                    style: const TextStyle(fontSize: 14, color: AppTheme.textHint),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDetail,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    children: [
                      _buildMemberSection(l),
                      const SizedBox(height: 16),
                      _buildInfoSection(l),
                      const SizedBox(height: 16),
                      _buildSettingsSection(l),
                      const SizedBox(height: 16),
                      _buildActionSection(l),
                    ],
                  ),
                ),
    );
  }

  /// 成员区域 —— 头像网格 + 邀请/移出按钮（管理员可见）
  Widget _buildMemberSection(AppLocalizations l) {
    // 最多显示的成员头像数量（预留位置给 +/- 按钮）
    final adminButtonsCount = _isAdmin ? (_isOwner ? 2 : 2) : 0;
    final maxAvatarSlots = _showAllMembers ? _members.length : (_membersPerRow * _maxRows - adminButtonsCount);
    final visibleMembers = _members.take(maxAvatarSlots).toList();
    final hasMore = !_showAllMembers && _members.length > maxAvatarSlots;

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
          // 标题
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Text(
                  l.get('group_members'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_members.length}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.primaryColor),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 头像网格
          Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - 8 * (_membersPerRow - 1)) / _membersPerRow;
                return Wrap(
                  spacing: 8,
                  runSpacing: 12,
                  children: [
                    ...visibleMembers.map((m) => _buildMemberTile(m, itemWidth, l)),
                    if (_isAdmin) _buildActionTile(
                      icon: Icons.add,
                      label: l.get('invite_members'),
                      color: AppTheme.primaryColor,
                      width: itemWidth,
                      onTap: _inviteMembers,
                    ),
                    if (_isAdmin) _buildActionTile(
                      icon: Icons.remove,
                      label: l.get('kick_member'),
                      color: AppTheme.dangerColor,
                      width: itemWidth,
                      onTap: _batchKickMembers,
                    ),
                  ],
                );
              },
            ),
          ),

          // 查看更多
          if (hasMore)
            InkWell(
              onTap: () => setState(() => _showAllMembers = true),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppTheme.dividerColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${l.get('more_members')} (${_members.length})',
                      style: const TextStyle(fontSize: 13, color: AppTheme.primaryColor),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down, size: 16, color: AppTheme.primaryColor),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMemberTile(GroupMemberModel m, double width, AppLocalizations l) {
    final isMe = m.userId == _currentUserId;
    return SizedBox(
      width: width,
      child: GestureDetector(
        onTap: () {
          if (_isAdmin && !isMe) {
            _showMemberActions(m);
          } else if (!isMe) {
            _openMemberProfile(m);
          }
        },
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AvatarWidget(avatarPath: m.userAvatar, name: m.displayName, size: 44),
                if (m.isOwner)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.star, size: 12, color: AppTheme.warningColor),
                    ),
                  )
                else if (m.role == GroupMemberRole.admin)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.shield, size: 12, color: AppTheme.primaryColor),
                    ),
                  ),
                if (m.isMuted)
                  Positioned(
                    left: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.volume_off, size: 12, color: AppTheme.dangerColor),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              m.displayName,
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required double width,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: width,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.3), width: 1),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// 群信息区域：群头像、群名称、群简介、群公告
  Widget _buildInfoSection(AppLocalizations l) {
    final group = _group!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          // 群头像（admin 可编辑）
          _buildAvatarRow(l, group),
          const Divider(height: 1, indent: 52),
          // 群名称
          _buildEditableInfoRow(
            icon: Icons.chat_bubble_rounded,
            iconColor: AppTheme.primaryColor,
            label: l.get('group_name'),
            value: group.name,
            canEdit: _isAdmin,
            onTap: () => _editField('name', group.name, l.get('edit_group_name'), maxLength: 50),
          ),
          const Divider(height: 1, indent: 52),
          // 群简介
          _buildEditableInfoRow(
            icon: Icons.info_outline,
            iconColor: AppTheme.textSecondary,
            label: l.get('group_description'),
            value: group.description.isNotEmpty ? group.description : '',
            emptyHint: l.get('group_announcement_empty'),
            canEdit: _isAdmin,
            onTap: () => _editField('description', group.description, l.get('edit_group_desc'), maxLines: 3, maxLength: 500),
          ),
          const Divider(height: 1, indent: 52),
          // 群公告（多行预览 + 点击查看详情）
          _buildAnnouncementRow(l, group),
        ],
      ),
    );
  }

  Widget _buildAvatarRow(AppLocalizations l, GroupModel group) {
    return InkWell(
      onTap: _isAdmin && !_isUploadingAvatar ? _pickAndUploadAvatar : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.image_outlined, size: 20, color: AppTheme.primaryColor),
            const SizedBox(width: 12),
            Text(l.get('group_avatar'), style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary)),
            const Spacer(),
            _isUploadingAvatar
                ? const SizedBox(width: 40, height: 40, child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)))
                : AvatarWidget(avatarPath: group.avatar, name: group.name, size: 40),
            if (_isAdmin)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(Icons.chevron_right, size: 18, color: AppTheme.textHint),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementRow(AppLocalizations l, GroupModel group) {
    final hasContent = group.announcement.isNotEmpty;
    final canEdit = _isAdmin;

    return InkWell(
      onTap: hasContent
          ? () => _showAnnouncementDetail(l, group)
          : (canEdit
              ? () => _editField('announcement', group.announcement, l.get('edit_group_announcement'), maxLines: 6, maxLength: 1000)
              : null),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.campaign_outlined, size: 20, color: AppTheme.warningColor),
                const SizedBox(width: 12),
                Text(l.get('group_announcement'), style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary)),
                const Spacer(),
                if (!hasContent)
                  Text(
                    l.get('group_announcement_empty'),
                    style: const TextStyle(fontSize: 14, color: AppTheme.textHint),
                  ),
                if (canEdit || hasContent)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.chevron_right, size: 18, color: AppTheme.textHint),
                  ),
              ],
            ),
            if (hasContent) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: Text(
                  group.announcement,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showAnnouncementDetail(AppLocalizations l, GroupModel group) async {
    final shouldEdit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.get('group_announcement')),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.5),
          child: SingleChildScrollView(
            child: Text(
              group.announcement,
              style: const TextStyle(fontSize: 14, height: 1.5, color: AppTheme.textPrimary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.get('cancel')),
          ),
          if (_isAdmin)
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.get('edit')),
            ),
        ],
      ),
    );
    if (shouldEdit == true && mounted) {
      await _editField('announcement', group.announcement, l.get('edit_group_announcement'), maxLines: 6, maxLength: 1000);
    }
  }

  Widget _buildEditableInfoRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    String? emptyHint,
    bool canEdit = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: canEdit ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary)),
            const SizedBox(width: 12),
            // Expanded + textAlign.end 让值文本占满剩余宽度并贴右对齐
            Expanded(
              child: Text(
                value.isNotEmpty ? value : (emptyHint ?? ''),
                style: TextStyle(
                  fontSize: 14,
                  color: value.isNotEmpty ? AppTheme.textSecondary : AppTheme.textHint,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
            ),
            if (canEdit)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.chevron_right, size: 18, color: AppTheme.textHint),
              ),
          ],
        ),
      ),
    );
  }

  /// 设置区域
  Widget _buildSettingsSection(AppLocalizations l) {
    final uid = _currentUserId;
    GroupMemberModel? me;
    if (uid != null) {
      for (final m in _members) {
        if (m.userId == uid) { me = m; break; }
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          _buildSwitchRow(
            icon: Icons.notifications_off_outlined,
            label: l.get('mute_notifications'),
            value: _muteNotifications,
            onChanged: _toggleMute,
          ),
          const Divider(height: 1, indent: 52),
          _buildSwitchRow(
            iconWidget: SvgPicture.asset(
              'assets/icon/top.svg',
              width: 20,
              height: 20,
              colorFilter: const ColorFilter.mode(
                AppTheme.textSecondary,
                BlendMode.srcIn,
              ),
            ),
            label: l.get('pin_chat'),
            value: _pinChat,
            onChanged: _togglePin,
            disabled: widget.groupId == 1, // 公共聊天室强制置顶
          ),
          // 全员禁言（仅群主/管理员可见可改）
          if (_isAdmin && _group != null) ...[
            const Divider(height: 1, indent: 52),
            _buildSwitchRow(
              icon: Icons.volume_off_outlined,
              label: l.get('group_all_mute'),
              value: _group!.isAllMuted,
              onChanged: _toggleAllMuted,
            ),
          ],
          const Divider(height: 1, indent: 52),
          _buildAliasRow(l, me?.alias ?? ''),
          const Divider(height: 1, indent: 52),
          _buildQrRow(l),
        ],
      ),
    );
  }

  Widget _buildQrRow(AppLocalizations l) {
    return InkWell(
      onTap: _showGroupQr,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.qr_code, size: 20, color: AppTheme.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(l.get('group_qr_title'), style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary)),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppTheme.textHint),
          ],
        ),
      ),
    );
  }

  void _showGroupQr() {
    if (_group == null) return;
    showDialog(
      context: context,
      builder: (_) => GroupQrDialog(
        groupId: _group!.id,
        groupName: _group!.name,
        groupAvatar: _group!.avatar,
      ),
    );
  }

  Widget _buildAliasRow(AppLocalizations l, String alias) {
    return InkWell(
      onTap: () => _editMyAlias(alias),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.badge_outlined, size: 20, color: AppTheme.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(l.get('group_my_alias'), style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary)),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                alias.isEmpty ? l.get('group_alias_empty') : alias,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: alias.isEmpty ? AppTheme.textHint : AppTheme.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: AppTheme.textHint),
          ],
        ),
      ),
    );
  }

  Future<void> _editMyAlias(String currentAlias) async {
    final l = AppLocalizations.of(context)!;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _EditFieldDialog(
        title: l.get('group_my_alias'),
        initialValue: currentAlias,
        maxLines: 1,
        maxLength: 50,
        cancelText: l.get('cancel'),
        confirmText: l.get('confirm'),
      ),
    );
    if (result == null || !mounted || result == currentAlias) return;
    final ok = await _groupService.setMyAlias(widget.groupId, result.trim());
    if (!mounted) return;
    if (ok) {
      _loadDetail();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.get('network_error')), backgroundColor: AppTheme.dangerColor),
      );
    }
  }

  Widget _buildSwitchRow({
    IconData? icon,
    Widget? iconWidget,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool disabled = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          iconWidget ?? Icon(icon, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary)),
          ),
          Switch.adaptive(
            value: value,
            onChanged: disabled ? null : onChanged,
            activeColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }

  /// 操作区域：清空聊天记录、退出/解散
  Widget _buildActionSection(AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _handleClearChat,
              icon: const Icon(Icons.delete_outline, size: 20),
              label: Text(l.get('clear_chat_history')),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.dangerColor,
                side: const BorderSide(color: AppTheme.dangerColor, width: 1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
          width: double.infinity,
          height: 48,
          child: (_isOwner && !(_group?.isPublicRoom ?? false))
              ? ElevatedButton.icon(
                  onPressed: _isActioning ? null : _disbandGroup,
                  icon: const Icon(Icons.delete_forever, size: 20),
                  label: Text(l.get('disband_group')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.dangerColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                )
              : OutlinedButton.icon(
                  onPressed: _isActioning ? null : _leaveGroup,
                  icon: const Icon(Icons.exit_to_app, size: 20),
                  label: Text(l.get('leave_group')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.dangerColor,
                    side: const BorderSide(color: AppTheme.dangerColor, width: 1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// 群内禁言时长选项
class _MuteOption {
  final int minutes; // -1 表示永久
  final String label;
  const _MuteOption(this.minutes, this.label);
}

/// 编辑文本对话框（内部管理 TextEditingController 生命周期，避免过早 dispose）
class _EditFieldDialog extends StatefulWidget {
  final String title;
  final String initialValue;
  final int maxLines;
  final int maxLength;
  final String cancelText;
  final String confirmText;

  /// 弹窗宽度占屏幕比例（null=Material 默认窄弹窗；如 0.95 表示占 95%）
  final double? widthFactor;

  const _EditFieldDialog({
    required this.title,
    required this.initialValue,
    required this.maxLines,
    required this.maxLength,
    required this.cancelText,
    required this.confirmText,
    this.widthFactor,
  });

  @override
  State<_EditFieldDialog> createState() => _EditFieldDialogState();
}

class _EditFieldDialogState extends State<_EditFieldDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final wf = widget.widthFactor;

    return AlertDialog(
      title: Text(widget.title),
      // 通过 insetPadding 控制 dialog 与屏幕边缘距离，达到指定宽度比例
      insetPadding: wf != null
          ? EdgeInsets.symmetric(
              horizontal: screenWidth * (1 - wf) / 2,
              vertical: 24,
            )
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      content: SizedBox(
        // 宽模式下用 double.maxFinite 让 content 撑满 dialog 宽度
        width: wf != null ? double.maxFinite : null,
        child: TextField(
          controller: _ctrl,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          autofocus: true,
          decoration: InputDecoration(counterText: '', hintText: widget.title),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.cancelText),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: Text(widget.confirmText),
        ),
      ],
    );
  }
}

