import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../../widgets/post/image_picker_section.dart' show isVideoFile;
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
import '../wallet/reward_pay_dialog.dart';
import '../../config/currency.dart';
import '../../widgets/coin_icon.dart';
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
                  '${AppLocalizations.of(context)!.get("clue_count")} (${post.clueCount})',
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
                    child: Text(AppLocalizations.of(context)!.get('no_clues'), style: TextStyle(color: AppTheme.textHint)),
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
              // 悬赏标签
              if (post.hasReward) ...[
                const SizedBox(height: 12),
                _buildRewardBanner(post),
              ],
              const SizedBox(height: 16),
              Text(post.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
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
            final url = images[index].imageUrl;
            if (isVideoFile(url)) {
              return _VideoItem(videoUrl: url);
            }
            return CachedNetworkImage(
              imageUrl: url,
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
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.get('login_required'))));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.get('login_required'))));
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

  Widget _buildRewardBanner(PostModel post) {
    final l = AppLocalizations.of(context)!;
    final remaining = post.rewardRemaining;
    final progress = post.rewardAmount > 0 ? post.rewardPaid / post.rewardAmount : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFD54F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monetization_on, color: Color(0xFFFF8F00), size: 20),
              const SizedBox(width: 6),
              Text(l.get('reward_bounty'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFFF8F00))),
              const Spacer(),
              CoinAmount(
                amount: post.rewardAmount,
                iconSize: 14,
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFF8F00)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 进度条
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.6),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF8F00)),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${l.get("reward_paid_label")} ${CurrencyConfig.format(post.rewardPaid)}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
              Text(
                '${l.get("reward_remaining")}: ${CurrencyConfig.format(remaining)}',
                style: const TextStyle(fontSize: 11, color: Color(0xFFFF8F00)),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
    UserProfilePage.show(context, userId: user.id, nickname: user.nickname, avatar: user.avatar, userCode: user.userCode, isOfficial: user.isOfficialService);
  }

  Widget _buildClueCard(ClueModel clue) {
    final auth = context.read<AuthProvider>();
    final friendProvider = context.read<FriendProvider>();
    final clueUser = clue.user;
    final isMe = auth.isLoggedIn && clueUser != null && auth.user?.id == clueUser.id;
    final isFriend = clueUser != null && friendProvider.isFriend(clueUser.id);
    final l = AppLocalizations.of(context)!;

    // 是否显示发放悬赏按钮：发布者看到别人的线索 + 有剩余悬赏
    final isOwner = auth.isLoggedIn && _post != null && auth.user?.id == _post!.userId;
    final showPayReward = isOwner && _post!.hasReward && _post!.rewardRemaining > 0 && !isMe;

    return Column(
      children: [
        ClueCard(
          clue: clue,
          isMe: isMe,
          isFriend: isFriend,
          isLoggedIn: auth.isLoggedIn,
          onUserTap: clueUser != null ? () => _showUserProfile(clueUser) : null,
          onAddFriend: clueUser != null ? () async {
            final error = await context.read<FriendProvider>().sendRequest(toId: clueUser.id);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(error ?? l.get('request_sent')),
              backgroundColor: error != null ? AppTheme.warningColor : AppTheme.successColor,
            ));
          } : null,
        ),
        if (showPayReward)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showRewardPay(clue),
                icon: const Icon(Icons.monetization_on_outlined, size: 16, color: Color(0xFFFF8F00)),
                label: Text(l.get('reward_pay_clue'), style: const TextStyle(color: Color(0xFFFF8F00))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFFD54F)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showRewardPay(ClueModel clue) async {
    if (_post == null) return;
    final result = await showDialog(
      context: context,
      builder: (_) => RewardPayDialog(
        postId: _post!.id,
        clueId: clue.id,
        clueUserName: clue.user?.nickname,
        maxAmount: _post!.rewardRemaining,
      ),
    );
    if (result == true) _loadDetail();
  }

  Future<void> _share() async {
    if (_post == null) return;
    final l = AppLocalizations.of(context)!;
    final appConfig = context.read<AppConfigProvider>();
    final baseUrl = appConfig.about['website_url'] ?? 'https://gohome.douwen.me';
    final shareUrl = '$baseUrl/#/post/detail?id=${_post!.id}';
    final shareText = '${l.get("app_name")} - ${_post!.categoryText}：${_post!.name}\n$shareUrl';

    // 先复制链接到剪贴板
    await Clipboard.setData(ClipboardData(text: shareText));

    if (!mounted) return;

    // 弹出分享底部面板
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ShareSheet(
        shareText: shareText,
        shareUrl: shareUrl,
      ),
    );
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

// ==================== 分享面板 ====================

class _ShareSheet extends StatelessWidget {
  final String shareText;
  final String shareUrl;

  const _ShareSheet({required this.shareText, required this.shareUrl});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拽指示条
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // 已复制提示
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.successColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppTheme.successColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.get('share_link_copied'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.successColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 分享到提示
            Text(
              l.get('share_to_paste'),
              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),

            // 分享平台按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareTarget(
                  context,
                  icon: 'wechat',
                  label: l.get('share_wechat'),
                  color: const Color(0xFF07C160),
                  onTap: () {
                    Navigator.pop(context);
                    _openWeChat();
                  },
                ),
                _buildShareTarget(
                  context,
                  icon: 'telegram',
                  label: 'Telegram',
                  color: const Color(0xFF0088CC),
                  onTap: () {
                    Navigator.pop(context);
                    _shareToTelegram();
                  },
                ),
                _buildShareTarget(
                  context,
                  icon: 'whatsapp',
                  label: 'WhatsApp',
                  color: const Color(0xFF25D366),
                  onTap: () {
                    Navigator.pop(context);
                    _shareToWhatsApp();
                  },
                ),
                Builder(builder: (sheetCtx) {
                  return _buildShareTarget(
                    sheetCtx,
                    icon: 'copy',
                    label: l.get('copy_link'),
                    color: AppTheme.textSecondary,
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: shareText));
                      final messenger = ScaffoldMessenger.of(sheetCtx);
                      Navigator.pop(sheetCtx);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(l.get('copied')),
                          backgroundColor: AppTheme.successColor,
                        ),
                      );
                    },
                  );
                }),
              ],
            ),
            const SizedBox(height: 20),

            // 取消按钮
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.grey[100],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  l.get('cancel'),
                  style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareTarget(
    BuildContext context, {
    required String icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(child: _buildBrandIcon(icon)),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandIcon(String brand) {
    switch (brand) {
      case 'wechat':
        return CustomPaint(size: const Size(28, 28), painter: _WeChatPainter());
      case 'telegram':
        return CustomPaint(size: const Size(28, 28), painter: _TelegramPainter());
      case 'whatsapp':
        return CustomPaint(size: const Size(28, 28), painter: _WhatsAppPainter());
      case 'copy':
        return const Icon(Icons.copy, size: 24, color: Colors.white);
      default:
        return const Icon(Icons.share, size: 24, color: Colors.white);
    }
  }

  void _openWeChat() async {
    // 微信无法直接通过 URL scheme 传递文本，只能尝试打开微信
    // 用户需要手动粘贴已复制的内容
    final uri = Uri.parse('weixin://');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _shareToTelegram() async {
    final uri = Uri.parse('https://t.me/share/url?url=${Uri.encodeComponent(shareUrl)}&text=${Uri.encodeComponent(shareText)}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _shareToWhatsApp() async {
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(shareText)}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}

// ==================== 视频播放组件 ====================

class _VideoItem extends StatefulWidget {
  final String videoUrl;
  const _VideoItem({required this.videoUrl});

  @override
  State<_VideoItem> createState() => _VideoItemState();
}

class _VideoItemState extends State<_VideoItem> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _playing = false;
  bool _hasError = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onVideoStatusChanged() {
    if (_controller == null || !mounted) return;
    final value = _controller!.value;
    if (value.position >= value.duration && value.duration > Duration.zero) {
      _controller!.pause();
      _controller!.seekTo(Duration.zero);
      setState(() => _playing = false);
    }
  }

  Future<void> _initAndPlay() async {
    try {
      if (_controller == null) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
        _controller!.addListener(_onVideoStatusChanged);
        await _controller!.initialize();
        if (!mounted) return;
        _initialized = true;
      }
      _controller!.play();
      if (mounted) setState(() => _playing = true);
    } catch (e) {
      debugPrint('[_VideoItem] init error: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: Colors.black87,
        child: const Center(
          child: Icon(Icons.error_outline, color: Colors.white54, size: 48),
        ),
      );
    }

    if (_initialized && _playing) {
      return Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),
          ),
          Positioned(
            bottom: 8, right: 8,
            child: GestureDetector(
              onTap: () {
                _controller!.pause();
                setState(() => _playing = false);
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.pause, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: _initAndPlay,
      child: Container(
        color: Colors.black87,
        child: const Center(
          child: Icon(Icons.play_circle_outline, color: Colors.white, size: 64),
        ),
      ),
    );
  }
}

// ==================== 品牌图标绘制 ====================

/// 微信图标
class _WeChatPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final cx = size.width / 2;
    final cy = size.height / 2;
    // 大气泡
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - 1, cy + 1), width: size.width * 0.62, height: size.height * 0.5), paint);
    // 小气泡
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + 5, cy - 4), width: size.width * 0.46, height: size.height * 0.38), paint);
    // 大气泡的眼睛
    final eyePaint = Paint()..color = const Color(0xFF07C160)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx - 4, cy + 0.5), 1.5, eyePaint);
    canvas.drawCircle(Offset(cx + 2, cy + 0.5), 1.5, eyePaint);
    // 小气泡的眼睛
    canvas.drawCircle(Offset(cx + 3, cy - 4.5), 1.2, eyePaint);
    canvas.drawCircle(Offset(cx + 7.5, cy - 4.5), 1.2, eyePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Telegram 图标（纸飞机）
class _TelegramPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(w * 0.12, h * 0.48)
      ..lineTo(w * 0.88, h * 0.18)
      ..lineTo(w * 0.68, h * 0.82)
      ..lineTo(w * 0.48, h * 0.60)
      ..close();
    canvas.drawPath(path, paint);

    final path2 = Path()
      ..moveTo(w * 0.48, h * 0.60)
      ..lineTo(w * 0.62, h * 0.82)
      ..lineTo(w * 0.68, h * 0.82)
      ..lineTo(w * 0.48, h * 0.60)
      ..close();
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// WhatsApp 图标（电话气泡）
class _WhatsAppPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final cx = size.width / 2;
    final cy = size.height / 2;

    // 气泡圆
    canvas.drawCircle(Offset(cx, cy), size.width * 0.38, paint);

    // 电话听筒
    final phonePaint = Paint()
      ..color = const Color(0xFF25D366)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final phonePath = Path()
      ..moveTo(cx - 4.5, cy + 3)
      ..quadraticBezierTo(cx - 4.5, cy - 4, cx, cy - 4.5)
      ..quadraticBezierTo(cx + 4.5, cy - 4, cx + 4.5, cy + 3);
    canvas.drawPath(phonePath, phonePaint);

    // 听筒两端
    canvas.drawLine(Offset(cx - 5, cy + 0.5), Offset(cx - 4, cy + 4), phonePaint);
    canvas.drawLine(Offset(cx + 5, cy + 0.5), Offset(cx + 4, cy + 4), phonePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
