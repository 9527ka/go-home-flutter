import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/conversation.dart';
import '../../models/group.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/conversation_provider.dart';
import '../../providers/friend_provider.dart';
import '../../services/group_service.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/group_grid_avatar.dart';

class ConversationListPage extends StatefulWidget {
  const ConversationListPage({super.key});

  @override
  State<ConversationListPage> createState() => _ConversationListPageState();
}

class _ConversationListPageState extends State<ConversationListPage> {
  /// 当前打开左滑抽屉的会话 key（同一时刻仅允许一项打开，避免多项叠加）
  String? _openSwipeKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final conversationProvider = context.read<ConversationProvider>();
      final chatProvider = context.read<ChatProvider>();
      conversationProvider.bindChatProvider(chatProvider);
      conversationProvider.setCurrentUserId(context.read<AuthProvider>().user?.id);
      conversationProvider.setTranslator(AppLocalizations.of(context)!.get);
      conversationProvider.loadConversationsIfEmpty();
      conversationProvider.loadMutedPreferences();
      // 拉取最新的好友申请数量与最近一条申请（用于顶部"新的朋友"入口）
      final friendProvider = context.read<FriendProvider>();
      friendProvider.setTranslator(AppLocalizations.of(context)!.get);
      friendProvider.loadRequests();
    });
  }

  /// 通过邀请链接加入群：弹出输入框，提交后调用后端
  Future<void> _handleJoinByInvite() async {
    final l = AppLocalizations.of(context)!;
    final ctrl = TextEditingController();
    final input = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.get('join_group_by_invite')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l.get('paste_invite_link_hint'),
            border: const OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.get('cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(l.get('confirm')),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (input == null || input.isEmpty || !mounted) return;

    // 解析 token：支持完整 gohome://group/invite/<token> 或纯 token
    final m = RegExp(r'([a-fA-F0-9]{32})').firstMatch(input);
    if (m == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.get('invite_link_invalid')), backgroundColor: AppTheme.dangerColor),
      );
      return;
    }
    final token = m.group(1)!;

    final result = await GroupService().joinByToken(token);
    if (!mounted) return;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.get('invite_link_invalid')), backgroundColor: AppTheme.dangerColor),
      );
      return;
    }
    final groupId = result['group_id'] as int? ?? 0;
    if (groupId > 0) {
      // 刷新会话列表，跳转到群聊
      context.read<ConversationProvider>().loadConversations();
      Navigator.pushNamed(context, AppRoutes.groupChat, arguments: groupId);
    }
  }

  Future<void> _handleCreateGroup() async {
    final result = await Navigator.pushNamed(context, AppRoutes.groupCreate);
    if (!mounted || result == null || result is! GroupModel) return;

    final group = result;
    final l = AppLocalizations.of(context)!;

    // 在会话列表中插入新群会话，显示创建成功消息
    context.read<ConversationProvider>().onMessageSent(
          targetId: group.id,
          targetType: 'group',
          content: l.get('group_created'),
          name: group.name,
          avatar: group.avatar,
        );

    // 直接跳转到群聊页面
    if (mounted) {
      Navigator.pushNamed(context, AppRoutes.groupChat, arguments: group.id);
    }
  }

  bool _isConvMuted(ConversationModel conv) {
    // 直接从 Provider 读，由 notifyListeners 驱动 UI 立即刷新
    return context.read<ConversationProvider>().isMuted(conv.targetId, conv.targetType);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final conversationProvider = context.watch<ConversationProvider>();
    final chatProvider = context.watch<ChatProvider>();
    final friendProvider = context.watch<FriendProvider>();

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
            icon: const Icon(Icons.contacts_outlined, size: 22),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.friendListPage),
            tooltip: l.get('contacts'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 22),
            onSelected: (value) {
              switch (value) {
                case 'add_friend':
                  Navigator.pushNamed(context, AppRoutes.friendSearch);
                  break;
                case 'create_group':
                  _handleCreateGroup();
                  break;
                case 'join_by_invite':
                  _handleJoinByInvite();
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
                value: 'join_by_invite',
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_scanner_outlined, size: 20, color: AppTheme.textPrimary),
                    const SizedBox(width: 8),
                    Text(l.get('join_group_by_invite')),
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
          await friendProvider.loadRequests();
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            // 顶部"新的朋友"入口（有待处理申请时显示）
            if (friendProvider.hasNewRequests)
              _buildFriendRequestsEntry(friendProvider, l),
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
  //  顶部"新的朋友"入口（仿微信）
  // ============================================================

  Widget _buildFriendRequestsEntry(FriendProvider fp, AppLocalizations l) {
    final count = fp.pendingRequestCount;
    final nickname = fp.latestRequesterNickname;
    final subtitle = nickname.isNotEmpty
        ? '$nickname ${l.get('friend_request_wants_to_add')}'
        : l.get('new_friend_requests_count').replaceAll('{n}', '$count');
    final timeStr = fp.latestRequestTime.isNotEmpty
        ? _formatTime(context, fp.latestRequestTime)
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: () async {
          await Navigator.pushNamed(context, AppRoutes.friendRequests);
          if (!mounted) return;
          // 返回后刷新数量（已处理的申请会从列表消失）
          context.read<FriendProvider>().loadRequests();
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
                // 头像位：person_add 图标 + 右上角未读数
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1_rounded,
                        color: AppTheme.primaryColor,
                        size: 26,
                      ),
                    ),
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        decoration: BoxDecoration(
                          color: AppTheme.dangerColor,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          count > 99 ? '99+' : '$count',
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
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.get('new_friends_entry'),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (timeStr.isNotEmpty)
                            Text(
                              timeStr,
                              style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
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
      ),
    );
  }

  // ============================================================
  //  会话列表项 — 左滑操作按钮（仿微信：已读 / 置顶 / 删除）
  // ============================================================

  Widget _buildDismissibleConversation(ConversationModel conv, AppLocalizations l) {
    final convProvider = context.read<ConversationProvider>();
    final isPinned = convProvider.isPinned(conv.targetId, conv.targetType);
    // 公共聊天室强制置顶，不允许切换
    final isPublicRoom = conv.isGroup && conv.targetId == ConversationProvider.kPublicRoomGroupId;
    final swipeKey = '${conv.targetType}_${conv.targetId}';

    final actions = <_SwipeAction>[
      if (conv.hasUnread)
        _SwipeAction(
          color: AppTheme.primaryColor,
          icon: const Icon(Icons.done_all, color: Colors.white, size: 20),
          label: l.get('mark_as_read'),
          onTap: () {
            context.read<ConversationProvider>().markRead(conv.targetId, conv.targetType);
          },
        ),
      if (!isPublicRoom)
        _SwipeAction(
          color: AppTheme.warningColor,
          // 置顶用 SVG 图标（白色 tint 适配彩色按钮背景）
          icon: SvgPicture.asset(
            'assets/icon/top.svg',
            width: 20,
            height: 20,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
          label: isPinned ? l.get('unpin_conversation') : l.get('pin_conversation'),
          onTap: () {
            context
                .read<ConversationProvider>()
                .setPinned(conv.targetId, conv.targetType, !isPinned);
          },
        ),
      _SwipeAction(
        color: AppTheme.dangerColor,
        icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
        label: l.get('delete_conversation'),
        onTap: () => _handleDeleteConversation(conv, l),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: _SwipeActionTile(
        swipeKey: swipeKey,
        isOpen: _openSwipeKey == swipeKey,
        onOpenChanged: (k) {
          setState(() => _openSwipeKey = k);
        },
        actions: actions,
        child: _buildConversationItem(conv, l),
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
    final isPinned = context
        .watch<ConversationProvider>()
        .isPinned(conv.targetId, conv.targetType);

    return GestureDetector(
      onTap: () async {
        if (conv.isGroup) {
          await Navigator.pushNamed(context, AppRoutes.groupChat, arguments: conv.targetId);
        } else {
          await Navigator.pushNamed(context, AppRoutes.privateChat, arguments: {
            'friendId': conv.targetId,
            'friendName': conv.name,
            'friendAvatar': conv.avatar,
            'friendIsOfficial': conv.isOfficialService,
          });
        }
        if (!mounted) return;
        await context.read<ConversationProvider>().markRead(conv.targetId, conv.targetType);
        if (!mounted) return;
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
                avatar: conv.isGroup && conv.memberAvatars.isNotEmpty
                    ? GroupGridAvatar(
                        avatars: conv.memberAvatars,
                        names: conv.memberNames,
                        size: 48,
                      )
                    : AvatarWidget(avatarPath: conv.avatar, name: conv.name, size: 48, isOfficial: conv.isOfficialService),
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
                              if (isPinned) ...[
                                const SizedBox(width: 4),
                                SvgPicture.asset(
                                  'assets/icon/top.svg',
                                  width: 13,
                                  height: 13,
                                  colorFilter: const ColorFilter.mode(
                                    AppTheme.warningColor,
                                    BlendMode.srcIn,
                                  ),
                                ),
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

// ============================================================
//  自定义左滑抽屉
//  - 左滑露出右侧按钮面板（标记已读 / 置顶 / 删除…）
//  - 同一时刻仅允许一项打开，通过父级 [isOpen] + [onOpenChanged] 协调
//  - 打开时屏蔽前景点击（避免滑开后点到跳转），点击前景收起
// ============================================================

class _SwipeAction {
  /// 图标 Widget，调用方自行选择 `Icon(...)` 或 `SvgPicture.asset(...)`。
  /// 颜色/尺寸由调用方决定（通常 white + 20px 适配按钮面板）。
  final Widget icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SwipeAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class _SwipeActionTile extends StatefulWidget {
  final String swipeKey;
  final bool isOpen;
  final ValueChanged<String?> onOpenChanged;
  final List<_SwipeAction> actions;
  final Widget child;

  const _SwipeActionTile({
    required this.swipeKey,
    required this.isOpen,
    required this.onOpenChanged,
    required this.actions,
    required this.child,
  });

  @override
  State<_SwipeActionTile> createState() => _SwipeActionTileState();
}

class _SwipeActionTileState extends State<_SwipeActionTile> {
  static const double _btnWidth = 72;
  double _offset = 0;

  double get _totalWidth => widget.actions.length * _btnWidth;

  @override
  void didUpdateWidget(covariant _SwipeActionTile old) {
    super.didUpdateWidget(old);
    // 外部将 isOpen 改为 false 时（例如其他项打开），自动收起本项
    if (!widget.isOpen && _offset != 0) {
      setState(() => _offset = 0);
    }
  }

  void _handleDragUpdate(DragUpdateDetails d) {
    setState(() {
      _offset = (_offset + (-d.delta.dx)).clamp(0.0, _totalWidth);
    });
  }

  void _handleDragEnd(DragEndDetails d) {
    final velocity = d.primaryVelocity ?? 0;
    // 过半 or 向左快滑 → 打开；否则收起
    final shouldOpen = _offset > _totalWidth / 2 || velocity < -300;
    setState(() => _offset = shouldOpen ? _totalWidth : 0);
    widget.onOpenChanged(shouldOpen ? widget.swipeKey : null);
  }

  void _close() {
    if (_offset != 0) {
      setState(() => _offset = 0);
    }
    widget.onOpenChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.actions.isEmpty) return widget.child;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          // 底层按钮面板（右侧固定宽度）
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: SizedBox(
              width: _totalWidth,
              child: Row(
                children: widget.actions.map(_buildActionButton).toList(),
              ),
            ),
          ),
          // 前景：随拖拽左移
          Transform.translate(
            offset: Offset(-_offset, 0),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: _handleDragUpdate,
              onHorizontalDragEnd: _handleDragEnd,
              // 抽屉打开时点击收起；关闭状态让 child 自己处理 tap
              onTap: widget.isOpen ? _close : null,
              child: IgnorePointer(
                ignoring: widget.isOpen,
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(_SwipeAction a) {
    return SizedBox(
      width: _btnWidth,
      child: GestureDetector(
        onTap: () {
          // 先收起再触发动作（保留视觉反馈时机）
          setState(() => _offset = 0);
          widget.onOpenChanged(null);
          a.onTap();
        },
        child: Container(
          color: a.color,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              a.icon,
              const SizedBox(height: 2),
              Text(
                a.label,
                style: const TextStyle(color: Colors.white, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
