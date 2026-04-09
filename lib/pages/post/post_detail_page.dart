import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/post.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/friend_provider.dart';
import '../../providers/app_config_provider.dart';
import '../../providers/interaction_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../services/post_service.dart';
import '../../services/favorite_service.dart';
import '../wallet/donate_dialog.dart';
import '../wallet/boost_dialog.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/disclaimer_banner.dart';
import '../../widgets/ai_banner.dart';
import '../../widgets/report_dialog.dart';
import '../../widgets/post/heart_animation.dart';
import '../../widgets/post/post_interaction_bar.dart';
import '../../widgets/post/post_activity_timeline.dart';
import '../../widgets/post/clue_card.dart';
import '../clue/clue_submit_page.dart';
import '../friend/user_profile_page.dart';

class PostDetailPage extends StatefulWidget {
  final int postId;
  const PostDetailPage({super.key, required this.postId});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> with SingleTickerProviderStateMixin {
  final _postService = PostService();
  PostModel? _post;
  bool _isLoading = true;

  // 双击点赞动画
  final List<HeartAnimation> _heartAnimations = [];

  @override
  void initState() {
    super.initState();
    _loadDetail();
    // 预加载钱包信息，避免捐赠/推广时余额为0
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appConfig = context.read<AppConfigProvider>();
      if (appConfig.walletEnabled) {
        context.read<WalletProvider>().loadWalletInfo();
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    try {
      _post = await _postService.getDetail(widget.postId);
      if (_post != null) {
        final ip = context.read<InteractionProvider>();
        ip.initPostLikeState(_post!.id, _post!.isLiked, _post!.likeCount);
      }
    } catch (e, stackTrace) {
      debugPrint('PostDetail load error: $e');
      debugPrint('$stackTrace');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.get('detail')),
        actions: [
          IconButton(icon: const Icon(Icons.share), onPressed: _share),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'report') _showReport();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'report', child: Text(AppLocalizations.of(context)!.get('report'))),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _post == null
              ? Center(child: Text(AppLocalizations.of(context)!.get('content_not_found')))
              : _buildBody(),
      bottomNavigationBar: _post != null ? _buildBottomActionBar() : null,
    );
  }

  Widget _buildBody() {
    final post = _post!;
    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildPostContent(post)),
            SliverToBoxAdapter(child: _buildInteractionBar(post)),
            // 捐赠和推广记录
            if (post.donations.isNotEmpty || post.boosts.isNotEmpty)
              SliverToBoxAdapter(
                child: PostActivityTimeline(
                  donations: post.donations,
                  boosts: post.boosts,
                ),
              ),
            // 线索标题
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  '线索 (${post.clueCount})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            // 线索列表
            if (post.clues.isNotEmpty)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildClueCard(post.clues[i]),
                  ),
                  childCount: post.clues.length,
                ),
              )
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text('暂无线索', style: TextStyle(color: AppTheme.textHint)),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
        // 双击点赞飘心
        ..._heartAnimations.map((h) => h.widget),
      ],
    );
  }

  // ==================== 帖子内容 ====================

  Widget _buildPostContent(PostModel post) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DisclaimerBanner(),

        // 发布者信息 + 关注按钮
        _buildAuthorRow(post),

        // 图片（支持双击点赞）
        if (post.images.isNotEmpty) _buildImageGallery(post.images),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 分类标签 + 状态
              Row(
                children: [
                  _buildTag(post.categoryText, AppTheme.getCategoryColor(post.category)),
                  const SizedBox(width: 8),
                  _buildTag(post.statusText, _getStatusColor(post.status)),
                  const Spacer(),
                  Text('${AppLocalizations.of(context)!.get('view_count')} ${post.viewCount}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
                ],
              ),
              const SizedBox(height: 16),
              Text(post.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (post.species.isNotEmpty) _infoRow(AppLocalizations.of(context)!.get('species'), post.species),
              const Divider(height: 32),
              Text(AppLocalizations.of(context)!.get('appearance'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(post.appearance, style: const TextStyle(fontSize: 15, height: 1.6)),
              if (post.description.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(AppLocalizations.of(context)!.get('extra_info'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(post.description, style: const TextStyle(fontSize: 15, height: 1.6)),
              ],
              const Divider(height: 32),
              Text(AppLocalizations.of(context)!.get('lost_info'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _infoRow(AppLocalizations.of(context)!.get('lost_time'), post.lostAt),
              _infoRow(AppLocalizations.of(context)!.get('lost_place'), post.locationText),
              if (post.disclaimer != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(post.disclaimer!, style: const TextStyle(fontSize: 13, color: Color(0xFF856404))),
                ),
              ],
              const SizedBox(height: 16),
              AiAnalysisPanel(imageCount: post.images.length, appearanceLength: post.appearance.length),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== 发布者 + 关注 ====================

  Widget _buildAuthorRow(PostModel post) {
    final user = post.user;
    if (user == null) return const SizedBox.shrink();
    final auth = context.read<AuthProvider>();
    final isMe = auth.isLoggedIn && auth.user?.id == user.id;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: !isMe ? () => _showUserProfile(user) : null,
            child: AvatarWidget(avatarPath: user.avatar, name: user.nickname, size: 44),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: !isMe ? () => _showUserProfile(user) : null,
              child: Text(user.nickname, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 图片（双击点赞） ====================

  Widget _buildImageGallery(List<PostImageModel> images) {
    return GestureDetector(
      onDoubleTap: () {
        _triggerDoubleTapLike();
      },
      child: SizedBox(
        height: 300,
        child: PageView.builder(
          itemCount: images.length,
          itemBuilder: (_, index) {
            return CachedNetworkImage(
              imageUrl: images[index].imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: Colors.grey[200]),
              errorWidget: (_, __, ___) => Container(
                color: Colors.grey[200],
                child: const Icon(Icons.broken_image, size: 48),
              ),
            );
          },
        ),
      ),
    );
  }

  void _triggerDoubleTapLike() {
    if (_post == null) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;
    final ip = context.read<InteractionProvider>();
    if (!ip.isPostLiked(_post!.id)) {
      ip.togglePostLike(_post!.id);
    }
    // 飘心动画
    final rng = DateTime.now().millisecondsSinceEpoch;
    final heart = HeartAnimation(
      key: ValueKey(rng),
      onComplete: () {
        if (mounted) {
          setState(() {
            _heartAnimations.removeWhere((h) => h.key == ValueKey(rng));
          });
        }
      },
    );
    setState(() => _heartAnimations.add(heart));
  }

  // ==================== 互动栏 ====================

  Widget _buildInteractionBar(PostModel post) {
    return Consumer<InteractionProvider>(
      builder: (context, ip, _) {
        final isLiked = ip.isPostLiked(post.id);
        final likeCount = ip.postLikeCount(post.id);

        return PostInteractionBar(
          isLiked: isLiked,
          likeCount: likeCount,
          shareCount: post.shareCount,
          isFavorited: post.isFavorited,
          onLike: () {
            final auth = context.read<AuthProvider>();
            if (!auth.isLoggedIn) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先登录')));
              return;
            }
            ip.togglePostLike(post.id);
          },
          onShare: _share,
          onFavorite: _toggleFavorite,
        );
      },
    );
  }

  bool _favToggling = false;
  Future<void> _toggleFavorite() async {
    if (_post == null || _favToggling) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先登录')));
      return;
    }
    _favToggling = true;
    // 乐观更新
    final wasFavorited = _post!.isFavorited;
    setState(() => _post = _post!.copyWith(isFavorited: !wasFavorited));
    try {
      final res = await FavoriteService().toggle(_post!.id);
      if (res['code'] == 0) {
        final data = res['data'];
        final isFav = data is Map ? (data['is_favorited'] == true) : !wasFavorited;
        if (mounted) setState(() => _post = _post!.copyWith(isFavorited: isFav));
      } else {
        // 回滚
        if (mounted) setState(() => _post = _post!.copyWith(isFavorited: wasFavorited));
      }
    } catch (e) {
      if (mounted) setState(() => _post = _post!.copyWith(isFavorited: wasFavorited));
    } finally {
      _favToggling = false;
    }
  }

  // ==================== 底部操作栏 ====================

  Widget _buildBottomActionBar() {
    final auth = context.read<AuthProvider>();
    final appConfig = context.read<AppConfigProvider>();
    final l = AppLocalizations.of(context)!;
    final walletOn = appConfig.walletEnabled;
    final isOwner = _canEdit();
    final showDonate = _post != null && _post!.userId != auth.user?.id && walletOn;
    final showBoost = _post != null && _post!.status == 1 && walletOn;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: Row(
          children: [
            // 提供线索按钮
            if (_post != null && !isOwner)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ClueSubmitPage(postId: _post!.id, postName: _post!.name),
                    ));
                  },
                  icon: const Icon(Icons.lightbulb_outline, size: 18),
                  label: Text(l.get('provide_clue')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            // 编辑按钮（仅发帖人看到）
            if (isOwner)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.pushNamed(context, AppRoutes.postEdit, arguments: _post!);
                    if (result == true) _loadDetail();
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(l.get('edit')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            // 捐赠按钮
            if (showDonate) ...[
              const SizedBox(width: 10),
              _buildActionChip(
                icon: Icons.favorite_border,
                label: l.get('donate'),
                color: Colors.orange,
                onTap: _showDonate,
              ),
            ],
            // 推广置顶按钮
            if (showBoost) ...[
              const SizedBox(width: 8),
              _buildActionChip(
                icon: Icons.rocket_launch_outlined,
                label: l.get('boost_post'),
                color: const Color(0xFF7C4DFF),
                onTap: _showBoost,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // ==================== 工具方法 ====================

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: AppTheme.textSecondary))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 0: return Colors.orange;
      case 1: return AppTheme.successColor;
      case 2: return AppTheme.primaryColor;
      case 3: return AppTheme.textHint;
      case 4: return AppTheme.dangerColor;
      case 5: return AppTheme.dangerColor;
      default: return AppTheme.textHint;
    }
  }

  bool _canEdit() {
    final auth = context.read<AuthProvider>();
    final isOwner = auth.isLoggedIn && _post != null && auth.user?.id == _post!.userId;
    return isOwner && _post!.canEdit;
  }

  void _showUserProfile(UserModel user) {
    UserProfilePage.show(context, userId: user.id, nickname: user.nickname, avatar: user.avatar, userCode: user.userCode);
  }

  Widget _buildClueCard(ClueModel clue) {
    final auth = context.read<AuthProvider>();
    final friendProvider = context.watch<FriendProvider>();
    final clueUser = clue.user;
    final isMe = auth.isLoggedIn && clueUser != null && auth.user?.id == clueUser.id;
    final isFriend = clueUser != null && friendProvider.isFriend(clueUser.id);
    final l = AppLocalizations.of(context)!;

    return ClueCard(
      clue: clue,
      isMe: isMe,
      isFriend: isFriend,
      isLoggedIn: auth.isLoggedIn,
      onUserTap: clueUser != null ? () => _showUserProfile(clueUser) : null,
      onAddFriend: clueUser != null ? () async {
        final error = await context.read<FriendProvider>().sendRequest(toId: clueUser.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error != null ? l.get(error) : l.get('request_sent')),
          backgroundColor: error != null ? AppTheme.dangerColor : AppTheme.successColor,
        ));
      } : null,
    );
  }

  Future<void> _share() async {
    if (_post == null) return;
    final text = '【回家了么】寻找${_post!.categoryText}：${_post!.name}\n'
        '走失地点：${_post!.locationText}\n'
        '联系方式：请通过平台查看\n'
        '请帮忙转发扩散，谢谢！';
    try {
      final box = context.findRenderObject() as RenderBox?;
      await Share.share(text,
          sharePositionOrigin: box != null ? Rect.fromLTWH(box.size.width - 50, 0, 50, 50) : null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.get('share_failed'))));
      }
    }
  }

  void _showReport() {
    showDialog(context: context, builder: (_) => ReportDialog(targetType: 1, targetId: widget.postId));
  }

  void _showDonate() async {
    if (_post == null) return;
    final result = await showDialog(context: context, builder: (_) => DonateDialog(postId: _post!.id, postAuthor: _post!.user?.nickname));
    if (result == true) _loadDetail();
  }

  void _showBoost() async {
    if (_post == null) return;
    final result = await showDialog(context: context, builder: (_) => BoostDialog(postId: _post!.id));
    if (result == true) _loadDetail();
  }
}
