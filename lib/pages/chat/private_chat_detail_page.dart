import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/conversation_provider.dart';
import '../../services/chat_service.dart';
import '../../services/friend_service.dart';
import '../../widgets/avatar_widget.dart';

/// 私聊聊天详情页
class PrivateChatDetailPage extends StatefulWidget {
  final int friendId;
  final String friendName;
  final String friendAvatar;
  final String friendUserCode;

  /// 清空本地消息的回调
  final VoidCallback? onClearMessages;

  const PrivateChatDetailPage({
    super.key,
    required this.friendId,
    required this.friendName,
    this.friendAvatar = '',
    this.friendUserCode = '',
    this.onClearMessages,
  });

  @override
  State<PrivateChatDetailPage> createState() => _PrivateChatDetailPageState();
}

class _PrivateChatDetailPageState extends State<PrivateChatDetailPage> {
  final _friendService = FriendService();
  final _chatService = ChatService();

  bool _muteNotifications = false;
  bool _pinChat = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _muteNotifications =
            prefs.getBool('conv_mute_private_${widget.friendId}') ?? false;
        _pinChat =
            prefs.getBool('conv_pin_private_${widget.friendId}') ?? false;
      });
    }
  }

  Future<void> _toggleMute(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('conv_mute_private_${widget.friendId}', value);
    if (mounted) {
      setState(() => _muteNotifications = value);
      context
          .read<ConversationProvider>()
          .setConversationMuted(widget.friendId, 'private', value);
    }
  }

  Future<void> _togglePin(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('conv_pin_private_${widget.friendId}', value);
    if (mounted) setState(() => _pinChat = value);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(l.get('chat_detail')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // 好友信息卡片
          _buildFriendInfoSection(l),

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

  /// 好友信息区域：头像、昵称、ID
  Widget _buildFriendInfoSection(AppLocalizations l) {
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
          // 可点击的头像
          GestureDetector(
            onTap: () => _showRemarkDialog(l),
            child: AvatarWidget(
              avatarPath: widget.friendAvatar,
              name: widget.friendName,
              size: 64,
            ),
          ),

          const SizedBox(height: 12),

          // 昵称
          Text(
            widget.friendName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),

          const SizedBox(height: 6),

          // ID
          if (widget.friendUserCode.isNotEmpty)
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: widget.friendUserCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('ID已复制'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${l.get("friend_id_label")}: ${widget.friendUserCode}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.copy, size: 14, color: AppTheme.textHint),
                ],
              ),
            ),

          const SizedBox(height: 4),

          // 点击头像提示
          Text(
            l.get('set_remark'),
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textHint,
            ),
          ),
        ],
      ),
    );
  }

  /// 设置区域：免打扰、置顶聊天
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
          _buildSwitchRow(
            icon: Icons.notifications_off_outlined,
            label: l.get('mute_notifications'),
            value: _muteNotifications,
            onChanged: _toggleMute,
          ),
          const Divider(height: 1, indent: 52),
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
              style:
                  const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
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

  /// 操作按钮区域
  Widget _buildActionSection(AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // 清空聊天记录
          _buildActionButton(
            icon: Icons.delete_outline,
            label: l.get('clear_chat_history'),
            color: AppTheme.dangerColor,
            onTap: () => _handleClearChat(l),
          ),

          const SizedBox(height: 12),

          // 投诉
          _buildActionButton(
            icon: Icons.flag_outlined,
            label: l.get('complaint'),
            color: AppTheme.warningColor,
            onTap: () => _handleComplaint(l),
          ),

          const SizedBox(height: 12),

          // 删除好友
          _buildActionButton(
            icon: Icons.person_remove_outlined,
            label: l.get('remove_friend'),
            color: AppTheme.dangerColor,
            onTap: () => _handleRemoveFriend(l),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  /// 编辑备注弹窗
  void _showRemarkDialog(AppLocalizations l) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.get('set_remark')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l.get('remark_hint'),
            border: const OutlineInputBorder(),
          ),
          maxLength: 20,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.get('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final remark = controller.text.trim();
              Navigator.pop(ctx);
              final success = await _friendService.updateRemark(
                  widget.friendId, remark);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? l.get('remark_updated')
                        : l.get('error_occurred')),
                    backgroundColor:
                        success ? AppTheme.successColor : AppTheme.dangerColor,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text(l.get('confirm')),
          ),
        ],
      ),
    );
  }

  /// 清空聊天记录
  void _handleClearChat(AppLocalizations l) async {
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
      widget.onClearMessages?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.get('chat_history_cleared')),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  /// 投诉
  void _handleComplaint(AppLocalizations l) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.get('complaint')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: l.get('complaint_hint'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.get('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = controller.text.trim();
              Navigator.pop(ctx);
              if (reason.isEmpty) return;
              final success = await _chatService.reportUser(
                widget.friendId,
                reason: reason,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? l.get('complaint_submitted')
                        : l.get('error_occurred')),
                    backgroundColor:
                        success ? AppTheme.successColor : AppTheme.dangerColor,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
              foregroundColor: Colors.white,
            ),
            child: Text(l.get('confirm')),
          ),
        ],
      ),
    );
  }

  /// 删除好友
  void _handleRemoveFriend(AppLocalizations l) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.get('remove_friend')),
        content: Text(l.get('remove_friend_confirm')),
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
      final success = await _friendService.removeFriend(widget.friendId);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.get('friend_removed')),
              backgroundColor: AppTheme.successColor,
            ),
          );
          // 删除好友后返回两层（回到会话列表）
          Navigator.pop(context); // 关闭详情页
          Navigator.pop(context); // 关闭聊天页
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.get('error_occurred')),
              backgroundColor: AppTheme.dangerColor,
            ),
          );
        }
      }
    }
  }
}
