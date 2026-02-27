import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/conversation.dart';
import '../../providers/chat_provider.dart';
import '../../providers/conversation_provider.dart';
import '../../widgets/avatar_widget.dart';

class ConversationListPage extends StatefulWidget {
  const ConversationListPage({super.key});

  @override
  State<ConversationListPage> createState() => _ConversationListPageState();
}

class _ConversationListPageState extends State<ConversationListPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 绑定 WebSocket handler，让会话列表能实时收到新消息更新
      final conversationProvider = context.read<ConversationProvider>();
      final chatProvider = context.read<ChatProvider>();
      conversationProvider.bindChatProvider(chatProvider);
      conversationProvider.loadConversations();
    });
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
            else if (conversationProvider.conversations.isEmpty)
              _buildEmptyHint(l)
            else
              ...conversationProvider.conversations.map(
                (conv) => _buildConversationItem(conv, l),
              ),
          ],
        ),
      ),
    );
  }

  /// 公共聊天室 - 置顶项
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
            color: AppTheme.primaryColor.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // 聊天室图标
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5BA0E8), Color(0xFF4A90D9)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.chat_bubble_rounded,
                  size: 24,
                  color: Colors.white,
                ),
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
                        // 置顶标签
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'TOP',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
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
              // 未读红点
              if (chatProvider.hasUnread)
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppTheme.dangerColor,
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppTheme.textHint, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// 会话列表项
  Widget _buildConversationItem(ConversationModel conv, AppLocalizations l) {
    return GestureDetector(
      onTap: () async {
        if (conv.isGroup) {
          await Navigator.pushNamed(context, AppRoutes.groupChat, arguments: conv.targetId);
        } else {
          // 私聊
          await Navigator.pushNamed(context, AppRoutes.privateChat, arguments: {
            'friendId': conv.targetId,
            'friendName': conv.name,
            'friendAvatar': conv.avatar,
          });
        }
        if (!mounted) return;
        // 标记已读
        context.read<ConversationProvider>().markRead(conv.targetId, conv.targetType);
        // 返回时重新加载会话列表，确保最后消息是最新的
        context.read<ConversationProvider>().loadConversations();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              AvatarWidget(avatarPath: conv.avatar, name: conv.name, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
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
                        if (conv.lastMsgTime.isNotEmpty)
                          Text(
                            _formatTime(context, conv.lastMsgTime),
                            style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conv.lastMessagePreview(l.get),
                            style: const TextStyle(fontSize: 13, color: AppTheme.textHint),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (conv.hasUnread)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.dangerColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              conv.unreadCount > 99 ? '99+' : '${conv.unreadCount}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
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

  Widget _buildEmptyHint(AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 30,
                color: AppTheme.primaryColor.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l.get('no_conversations'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l.get('no_conversations_hint'),
              style: const TextStyle(fontSize: 13, color: AppTheme.textHint),
            ),
          ],
        ),
      ),
    );
  }

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
