import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/conversation.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/conversation_provider.dart';
import '../../widgets/avatar_widget.dart';

class ConversationListPage extends StatefulWidget {
  const ConversationListPage({super.key});

  @override
  State<ConversationListPage> createState() => _ConversationListPageState();
}

class _ConversationListPageState extends State<ConversationListPage> {
  /// 本地免打扰状态缓存（避免每个 item 都 await SharedPreferences）
  final Map<String, bool> _muteCache = {};
  bool _chatRoomMuted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final conversationProvider = context.read<ConversationProvider>();
      final chatProvider = context.read<ChatProvider>();
      conversationProvider.bindChatProvider(chatProvider);
      conversationProvider.setCurrentUserId(context.read<AuthProvider>().user?.id);
      conversationProvider.loadConversations();
      _loadMutePreferences();
    });
  }

  Future<void> _loadMutePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final convProvider = context.read<ConversationProvider>();
    final newCache = <String, bool>{};
    _chatRoomMuted = prefs.getBool('chat_room_mute') ?? false;
    for (final conv in convProvider.conversations) {
      final key = 'conv_mute_${conv.targetType}_${conv.targetId}';
      newCache[key] = prefs.getBool(key) ?? false;
    }
    setState(() {
      _muteCache
        ..clear()
        ..addAll(newCache);
    });
  }

  bool _isConvMuted(ConversationModel conv) {
    final key = 'conv_mute_${conv.targetType}_${conv.targetId}';
    return _muteCache[key] ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final conversationProvider = context.watch<ConversationProvider>();
    final chatProvider = context.watch<ChatProvider>();

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(l.get('conversations')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined, size: 22),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.friendSearch),
            tooltip: l.get('add_friend'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 22),
            onSelected: (value) {
              switch (value) {
                case 'add_friend':
                  Navigator.pushNamed(context, AppRoutes.friendSearch);
                  break;
                case 'create_group':
                  Navigator.pushNamed(context, AppRoutes.groupCreate);
                  break;
                case 'blocked_users':
                  Navigator.pushNamed(context, AppRoutes.blockedUsers);
                  break;
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'add_friend',
                child: Row(
                  children: [
                    const Icon(Icons.person_add_outlined, size: 20, color: AppTheme.textPrimary),
                    const SizedBox(width: 8),
                    Text(l.get('add_friend')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'create_group',
                child: Row(
                  children: [
                    const Icon(Icons.group_add_outlined, size: 20, color: AppTheme.textPrimary),
                    const SizedBox(width: 8),
                    Text(l.get('create_group')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'blocked_users',
                child: Row(
                  children: [
                    const Icon(Icons.block_rounded, size: 20, color: AppTheme.textPrimary),
                    const SizedBox(width: 8),
                    Text(l.get('blocked_users')),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await conversationProvider.loadConversations();
          await chatProvider.checkUnread();
          await _loadMutePreferences();
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // 置顶：公共聊天室
            _buildPublicChatRoomItem(l, chatProvider),
            const SizedBox(height: 4),

            // 私聊和群聊会话列表
            if (conversationProvider.isLoading && conversationProvider.conversations.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ...conversationProvider.conversations.map(
                (conv) => _buildDismissibleConversation(conv, l),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  //  公共聊天室 - 置顶项（带角标未读数）
  // ============================================================

  Widget _buildPublicChatRoomItem(AppLocalizations l, ChatProvider chatProvider) {
    return GestureDetector(
      onTap: () async {
        await Navigator.pushNamed(context, AppRoutes.chatRoom);
        if (mounted) {
          chatProvider.checkUnread();
          context.read<ConversationProvider>().loadConversations();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppTheme.cardShadow,
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // 聊天室图标 + 未读角标
              _buildAvatarWithBadge(
                avatar: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5BA0E8), Color(0xFF4A90D9)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.chat_bubble_rounded, size: 24, color: Colors.white),
                ),
                unreadCount: chatProvider.hasUnread ? -1 : 0, // -1 = 红点
                isMuted: _chatRoomMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          l.get('public_chat_room'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'TOP',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                        if (_chatRoomMuted) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.notifications_off_outlined, size: 14, color: AppTheme.textHint),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.get('public_chat_room_desc'),
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

  // ============================================================
  //  会话列表项 — 左滑操作按钮（仿微信：已读 / 置顶 / 删除）
  // ============================================================

  Widget _buildDismissibleConversation(ConversationModel conv, AppLocalizations l) {
    final isMuted = _isConvMuted(conv);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            // 滑动后露出的操作按钮层
            Positioned.fill(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 标为已读
                  if (conv.hasUnread)
                    _swipeActionButton(
                      color: AppTheme.primaryColor,
                      icon: Icons.done_all,
                      label: l.get('mark_as_read'),
                      onTap: () {
                        context.read<ConversationProvider>().markRead(conv.targetId, conv.targetType);
                      },
                    ),
                  // 删除
                  _swipeActionButton(
                    color: AppTheme.dangerColor,
                    icon: Icons.delete_outline,
                    label: l.get('delete_conversation'),
                    onTap: () => _handleDeleteConversation(conv, l),
                  ),
                ],
              ),
            ),
            // 可滑动的前景内容
            Dismissible(
              key: ValueKey('${conv.targetType}_${conv.targetId}'),
              direction: DismissDirection.endToStart,
              dismissThresholds: const {DismissDirection.endToStart: 0.6},
              confirmDismiss: (_) async {
                return await _confirmDeleteConversation(conv, l);
              },
              onDismissed: (_) {
                context.read<ConversationProvider>().removeConversation(
                      conv.targetId,
                      conv.targetType,
                    );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l.get('conversation_deleted')),
                    backgroundColor: AppTheme.successColor,
                    action: SnackBarAction(
                      label: l.get('cancel'),
                      textColor: Colors.white,
                      onPressed: () => context.read<ConversationProvider>().loadConversations(),
                    ),
                  ),
                );
              },
              background: Container(
                decoration: BoxDecoration(
                  color: AppTheme.dangerColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
              ),
              child: _buildConversationItem(conv, l),
            ),
          ],
        ),
      ),
    );
  }

  Widget _swipeActionButton({
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        color: color,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _handleDeleteConversation(ConversationModel conv, AppLocalizations l) async {
    final confirmed = await _confirmDeleteConversation(conv, l);
    if (confirmed && mounted) {
      context.read<ConversationProvider>().removeConversation(conv.targetId, conv.targetType);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.get('conversation_deleted')),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  Future<bool> _confirmDeleteConversation(ConversationModel conv, AppLocalizations l) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.get('delete_conversation')),
        content: Text(l.get('delete_conversation_confirm')),
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
    return confirmed == true;
  }

  // ============================================================
  //  会话列表项 — 头像角标未读数 + 最后消息
  // ============================================================

  Widget _buildConversationItem(ConversationModel conv, AppLocalizations l) {
    final isMuted = _isConvMuted(conv);

    return GestureDetector(
      onTap: () async {
        if (conv.isGroup) {
          await Navigator.pushNamed(context, AppRoutes.groupChat, arguments: conv.targetId);
        } else {
          await Navigator.pushNamed(context, AppRoutes.privateChat, arguments: {
            'friendId': conv.targetId,
            'friendName': conv.name,
            'friendAvatar': conv.avatar,
          });
        }
        if (!mounted) return;
        context.read<ConversationProvider>().markRead(conv.targetId, conv.targetType);
        context.read<ConversationProvider>().loadConversations();
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // 头像 + 右上角未读角标
              _buildAvatarWithBadge(
                avatar: AvatarWidget(avatarPath: conv.avatar, name: conv.name, size: 48),
                unreadCount: conv.unreadCount,
                isMuted: isMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 第一行：名字 + 免打扰图标 + 时间
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  conv.name.isNotEmpty ? conv.name : l.get('unknown_user'),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isMuted) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.notifications_off_outlined, size: 14, color: AppTheme.textHint),
                              ],
                            ],
                          ),
                        ),
                        if (conv.lastMsgTime.isNotEmpty)
                          Text(
                            _formatTime(context, conv.lastMsgTime),
                            style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // 第二行：最后消息预览
                    Text(
                      conv.lastMessagePreview(l.get),
                      style: const TextStyle(fontSize: 13, color: AppTheme.textHint),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  //  头像 + 右上角未读角标
  //  unreadCount: 0=不显示, -1=红点(无数字), >0=显示数字
  // ============================================================

  Widget _buildAvatarWithBadge({
    required Widget avatar,
    required int unreadCount,
    required bool isMuted,
  }) {
    if (unreadCount == 0) return avatar;

    final badgeColor = isMuted ? AppTheme.textHint : AppTheme.dangerColor;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        // 未读角标 — 定位在头像右上角
        Positioned(
          top: -4,
          right: -4,
          child: unreadCount < 0
              // 红点（无数字）
              ? Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                )
              // 数字角标
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
      ],
    );
  }

  // ============================================================
  //  时间格式化
  // ============================================================

  String _formatTime(BuildContext context, String dateStr) {
    final l = AppLocalizations.of(context)!;
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return l.get('time_just_now');
      if (diff.inMinutes < 60) return l.get('time_minutes_ago').replaceAll('{n}', '${diff.inMinutes}');
      if (diff.inHours < 24) return l.get('time_hours_ago').replaceAll('{n}', '${diff.inHours}');
      if (diff.inDays < 7) return l.get('time_days_ago').replaceAll('{n}', '${diff.inDays}');
      if (diff.inDays < 365) return '${date.month}/${date.day}';
      return '${date.year}/${date.month}/${date.day}';
    } catch (e) {
      return dateStr;
    }
  }
}
