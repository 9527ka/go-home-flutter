import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/chat_message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/avatar_widget.dart';
import '../friend/user_profile_page.dart';

/// 公共聊天室详情页
class ChatRoomDetailPage extends StatefulWidget {
  const ChatRoomDetailPage({super.key});

  @override
  State<ChatRoomDetailPage> createState() => _ChatRoomDetailPageState();
}

class _ChatRoomDetailPageState extends State<ChatRoomDetailPage> {
  bool _muteNotifications = false;
  bool _pinChat = false;
  bool _showAllMembers = false;

  static const _membersPerRow = 5;
  static const _maxRows = 3;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _muteNotifications = prefs.getBool('chat_room_mute') ?? false;
        _pinChat = prefs.getBool('chat_room_pin') ?? false;
      });
    }
  }

  Future<void> _toggleMute(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('chat_room_mute', value);
    if (mounted) setState(() => _muteNotifications = value);
  }

  Future<void> _togglePin(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('chat_room_pin', value);
    if (mounted) setState(() => _pinChat = value);
  }

  /// 从聊天消息中提取唯一用户列表（去重，按最近发言排序）
  List<_MemberInfo> _extractMembers(List<ChatMessageModel> messages) {
    final Map<int, _MemberInfo> memberMap = {};
    // 从最新消息开始遍历，保留最近发言的用户靠前
    for (final msg in messages.reversed) {
      if (!memberMap.containsKey(msg.userId)) {
        memberMap[msg.userId] = _MemberInfo(
          userId: msg.userId,
          nickname: msg.nickname,
          avatar: msg.avatar,
          userCode: msg.userCode,
        );
      }
    }
    return memberMap.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final chatProvider = context.watch<ChatProvider>();
    final members = _extractMembers(chatProvider.messages);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(l.get('group_info')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // 群成员
          _buildMemberSection(l, members, chatProvider.onlineCount),

          const SizedBox(height: 16),

          // 群名称
          _buildInfoSection(l),

          const SizedBox(height: 16),

          // 设置开关
          _buildSettingsSection(l),

          const SizedBox(height: 16),

          // 操作按钮
          _buildActionSection(l),
        ],
      ),
    );
  }

  /// 群成员区域 — 头像网格
  Widget _buildMemberSection(AppLocalizations l, List<_MemberInfo> members, int onlineCount) {
    final currentUserId = context.read<AuthProvider>().user?.id;
    final maxVisible = _showAllMembers ? members.length : _membersPerRow * _maxRows;
    final visibleMembers = members.take(maxVisible).toList();
    final hasMore = members.length > _membersPerRow * _maxRows && !_showAllMembers;

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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Text(
                  l.get('group_members'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                if (onlineCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$onlineCount ${l.get('online')}',
                      style: const TextStyle(fontSize: 11, color: AppTheme.successColor),
                    ),
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 成员头像网格
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 12,
              children: visibleMembers.map((member) {
                final isMe = currentUserId != null && member.userId == currentUserId;
                return GestureDetector(
                  onTap: isMe
                      ? null
                      : () => UserProfilePage.show(
                            context,
                            userId: member.userId,
                            nickname: member.nickname,
                            avatar: member.avatar,
                            userCode: member.userCode,
                          ),
                  child: SizedBox(
                    width: (MediaQuery.of(context).size.width - 32 - 24 - 32) / _membersPerRow,
                    child: Column(
                      children: [
                        AvatarWidget(
                          avatarPath: member.avatar,
                          name: member.nickname,
                          size: 44,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          member.nickname,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // 查看更多按钮
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
                      '${l.get('more_members')} (${members.length})',
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

  /// 群信息区域：群名称、群简介、群公告
  Widget _buildInfoSection(AppLocalizations l) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          // 群名称
          _buildInfoRow(
            icon: Icons.chat_bubble_rounded,
            iconColor: AppTheme.primaryColor,
            label: l.get('group_name'),
            value: l.get('public_chat_room'),
          ),
          const Divider(height: 1, indent: 52),

          // 群简介
          _buildInfoRow(
            icon: Icons.info_outline,
            iconColor: AppTheme.textSecondary,
            label: l.get('group_description'),
            value: l.get('public_chat_room_desc'),
          ),
          const Divider(height: 1, indent: 52),

          // 群公告
          _buildInfoRow(
            icon: Icons.campaign_outlined,
            iconColor: AppTheme.warningColor,
            label: l.get('group_announcement'),
            value: l.get('group_announcement_empty'),
            valueColor: AppTheme.textHint,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: valueColor ?? AppTheme.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  /// 设置区域：消息免打扰、置顶聊天
  Widget _buildSettingsSection(AppLocalizations l) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          // 消息免打扰
          _buildSwitchRow(
            icon: Icons.notifications_off_outlined,
            label: l.get('mute_notifications'),
            value: _muteNotifications,
            onChanged: _toggleMute,
          ),
          const Divider(height: 1, indent: 52),

          // 置顶聊天
          _buildSwitchRow(
            icon: Icons.push_pin_outlined,
            label: l.get('pin_chat'),
            value: _pinChat,
            onChanged: _togglePin,
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }

  /// 操作区域：清空聊天记录、退出群聊
  Widget _buildActionSection(AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // 清空聊天记录
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 退出群聊（公共聊天室禁用）
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l.get('cannot_leave_public')),
                    backgroundColor: AppTheme.warningColor,
                  ),
                );
              },
              icon: const Icon(Icons.exit_to_app, size: 20),
              label: Text(l.get('leave_group')),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textHint,
                side: const BorderSide(color: AppTheme.dividerColor, width: 1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _handleClearChat() async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.get('clear_chat_history')),
        content: Text(l.get('clear_chat_confirm')),
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

    if (confirmed == true && mounted) {
      context.read<ChatProvider>().clearMessages();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.get('chat_history_cleared')),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }
}

/// 成员信息（从消息中提取）
class _MemberInfo {
  final int userId;
  final String nickname;
  final String avatar;
  final String userCode;

  _MemberInfo({
    required this.userId,
    required this.nickname,
    required this.avatar,
    this.userCode = '',
  });
}
