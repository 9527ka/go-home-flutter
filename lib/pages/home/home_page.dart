import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/conversation_provider.dart';
import '../../providers/friend_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/post_provider.dart';
import '../../widgets/post_card.dart';
import '../../widgets/disclaimer_banner.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 仅当 Splash 未预加载时才请求（避免重复加载）
      final postProvider = context.read<PostProvider>();
      if (postProvider.posts.isEmpty && !postProvider.isLoading) {
        postProvider.refresh();
      }

      // 仅登录用户才调用需要鉴权的接口（游客调用会触发 401）
      final auth = context.read<AuthProvider>();
      if (auth.isLoggedIn) {
        final chatProvider = context.read<ChatProvider>();
        if (!chatProvider.isLoading) {
          chatProvider.checkUnread();
        }
        // 绑定 ConversationProvider 到 ChatProvider，实时接收私聊/群聊新消息
        final conversationProvider = context.read<ConversationProvider>();
        conversationProvider.bindChatProvider(chatProvider);
        conversationProvider.loadConversations();
        // 绑定 FriendProvider，实时接收好友请求通知
        final friendProvider = context.read<FriendProvider>();
        friendProvider.bindChatProvider(chatProvider);
        friendProvider.fetchRequestCount();
        context.read<NotificationProvider>().fetchUnreadCount();
      }
    });
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
          _scrollCtrl.position.maxScrollExtent - 200) {
        context.read<PostProvider>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final postProvider = context.watch<PostProvider>();
    final auth = context.watch<AuthProvider>();
    final chatProvider = context.watch<ChatProvider>();
    final conversationProvider = context.watch<ConversationProvider>();
    final notificationProvider = context.watch<NotificationProvider>();

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: _buildAppBar(auth, chatProvider, conversationProvider, notificationProvider),
      body: Column(
        children: [
          // 免责声明
          const DisclaimerBanner(),

          // 分类筛选
          _buildCategoryFilter(postProvider),

          // 列表
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => postProvider.refresh(),
              color: AppTheme.primaryColor,
              child: postProvider.posts.isEmpty && !postProvider.isLoading
                  ? _buildEmpty(postProvider)
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      itemCount: postProvider.posts.length +
                          (postProvider.hasMore ? 1 : 0),
                      itemBuilder: (ctx, index) {
                        if (index >= postProvider.posts.length) {
                          return _buildLoadingMore();
                        }
                        return PostCard(
                          post: postProvider.posts[index],
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.postDetail,
                              arguments: postProvider.posts[index].id,
                            );
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
      ),

      // 发布按钮
      floatingActionButton: _buildFab(auth),
    );
  }

  PreferredSizeWidget _buildAppBar(AuthProvider auth, ChatProvider chatProvider,
      ConversationProvider conversationProvider, NotificationProvider notificationProvider) {
    final l = AppLocalizations.of(context)!;
    return AppBar(
      leading: Center(
        child: GestureDetector(
          onTap: () async {
            await Navigator.pushNamed(
              context,
              auth.isLoggedIn ? AppRoutes.profile : AppRoutes.login,
            );
            // 从个人中心返回后刷新未读数
            if (mounted) {
              notificationProvider.fetchUnreadCount();
            }
          },
          child: Container(
            margin: const EdgeInsets.only(left: 14),
            width: 34,
            height: 34,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: auth.isLoggedIn
                        ? AppTheme.primaryLight
                        : AppTheme.scaffoldBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    auth.isLoggedIn ? Icons.person : Icons.person_outline,
                    size: 20,
                    color: auth.isLoggedIn
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondary,
                  ),
                ),
                // 未读通知红点
                if (auth.isLoggedIn && notificationProvider.hasUnread)
                  Positioned(
                    right: -3,
                    top: -3,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.dangerColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF5BA0E8), Color(0xFF4A90D9)]),
              borderRadius: BorderRadius.circular(8),
            ),
            child:
                const Icon(Icons.home_rounded, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Text(l.get('app_name')),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded, size: 24),
          tooltip: l.get('search'),
          onPressed: () => Navigator.pushNamed(context, AppRoutes.postSearch),
        ),
        IconButton(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.chat_bubble_outline_rounded, size: 22),
              // 未读红点（公共聊天室 + 私聊/群聊）
              if (chatProvider.hasUnread || conversationProvider.hasUnread)
                Positioned(
                  right: -3,
                  top: -3,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.dangerColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          tooltip: l.get('conversations'),
          onPressed: () async {
            // 未登录用户需要先登录才能进入聊天室
            if (!auth.isLoggedIn) {
              Navigator.pushNamed(context, AppRoutes.login);
              return;
            }
            // HIDDEN_FEATURE: 会话列表 - 原逻辑进入 AppRoutes.conversations，现直接进入聊天室
            // 恢复时改回: await Navigator.pushNamed(context, AppRoutes.conversations);
            // 并恢复: conversationProvider.loadConversations();
            await Navigator.pushNamed(context, AppRoutes.chatRoom);
            if (mounted) {
              chatProvider.checkUnread();
            }
          },
        ),
      ],
    );
  }

  Widget _buildCategoryFilter(PostProvider provider) {
    final l = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          _filterChip(
              l.get('category_all'), null, null, Icons.apps_rounded, provider),
          const SizedBox(width: 8),
          _filterChip(l.get('category_elder'), 2, AppTheme.elderColor,
              Icons.elderly, provider),
          const SizedBox(width: 8),
          _filterChip(l.get('category_child'), 3, AppTheme.childColor,
              Icons.child_care, provider),
          const SizedBox(width: 8),
          _filterChip(l.get('category_other'), -1, AppTheme.otherColor,
              Icons.more_horiz_rounded, provider),
        ],
      ),
    );
  }

  Widget _filterChip(String label, int? category, Color? color, IconData icon,
      PostProvider provider) {
    final isSelected = provider.filterCategory == category;
    final chipColor = color ?? AppTheme.primaryColor;

    return Expanded(
      child: GestureDetector(
        onTap: () => provider.setCategory(category),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? chipColor.withOpacity(0.1) : AppTheme.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? chipColor.withOpacity(0.4)
                  : AppTheme.dividerColor,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: chipColor.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2)),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 20, color: isSelected ? chipColor : AppTheme.textHint),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? chipColor : AppTheme.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingMore() {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
              strokeWidth: 2.5, color: AppTheme.primaryColor),
        ),
      ),
    );
  }

  Widget _buildEmpty(PostProvider provider) {
    return ListView(
      // 允许下拉刷新
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.inbox_outlined,
                    size: 40, color: AppTheme.primaryColor.withOpacity(0.5)),
              ),
              const SizedBox(height: 20),
              Text(
                AppLocalizations.of(context)!.get('empty_title'),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.get('empty_hint'),
                style: const TextStyle(fontSize: 13, color: AppTheme.textHint),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFab(AuthProvider auth) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () {
          if (auth.isLoggedIn) {
            Navigator.pushNamed(context, AppRoutes.postCreate);
          } else {
            Navigator.pushNamed(context, AppRoutes.login);
          }
        },
        elevation: 0,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.edit_outlined, size: 20),
        label: Text(AppLocalizations.of(context)!.get('publish'),
            style: const TextStyle(
                fontWeight: FontWeight.w600, letterSpacing: 0.5)),
      ),
    );
  }
}
