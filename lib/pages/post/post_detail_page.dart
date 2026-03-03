import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/post.dart';
import '../../providers/auth_provider.dart';
import '../../services/post_service.dart';
import '../../widgets/disclaimer_banner.dart';
import '../../widgets/report_dialog.dart';
import '../clue/clue_submit_page.dart';

class PostDetailPage extends StatefulWidget {
  final int postId;
  const PostDetailPage({super.key, required this.postId});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final _postService = PostService();
  PostModel? _post;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    try {
      _post = await _postService.getDetail(widget.postId);
    } catch (e) {
      // 加载失败
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.get('detail')),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _share,
          ),
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
              : _buildContent(),
      bottomNavigationBar: _post != null ? _buildBottomBar() : null,
    );
  }

  Widget _buildContent() {
    final post = _post!;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ⚠️ 免责声明
          const DisclaimerBanner(),

          // 图片轮播
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
                    Text('${AppLocalizations.of(context)!.get('view_count')} ${post.viewCount}', style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
                  ],
                ),

                const SizedBox(height: 16),

                // 名字
                Text(
                  post.name,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 12),

                // 基本信息表格
                _infoRow(AppLocalizations.of(context)!.get('gender'), post.genderText),
                if (post.age.isNotEmpty) _infoRow(AppLocalizations.of(context)!.get('age'), post.age),
                if (post.species.isNotEmpty) _infoRow(AppLocalizations.of(context)!.get('species'), post.species),

                const Divider(height: 32),

                // 体貌特征
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

                // 走失信息
                Text(AppLocalizations.of(context)!.get('lost_info'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _infoRow(AppLocalizations.of(context)!.get('lost_time'), post.lostAt),
                _infoRow(AppLocalizations.of(context)!.get('lost_place'), post.locationText),

                const Divider(height: 32),

                // 联系方式
                Text(AppLocalizations.of(context)!.get('contact_info'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (post.contactName.isNotEmpty) _infoRow(AppLocalizations.of(context)!.get('contact_person'), post.contactName),
                _infoRow(AppLocalizations.of(context)!.get('contact_phone'), post.contactPhone),

                // ⚠️ 详情页免责声明
                if (post.disclaimer != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      post.disclaimer!,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF856404)),
                    ),
                  ),
                ],

                // 线索区
                if (post.clues.isNotEmpty) ...[
                  const Divider(height: 32),
                  Text(
                    '${AppLocalizations.of(context)!.get('clue_count')} (${post.clues.length})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...post.clues.map((clue) => _buildClueCard(clue)),
                ] else if (post.clueCount > 0) ...[
                  const Divider(height: 32),
                  Text(
                    '${AppLocalizations.of(context)!.get('clue_count')} (${post.clueCount})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)!.get('clue_view_hint'),
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ],

                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGallery(List<PostImageModel> images) {
    return SizedBox(
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
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          ),
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
      case 5: return AppTheme.dangerColor; // 举报屏蔽
      default: return AppTheme.textHint;
    }
  }

  Widget _buildClueCard(ClueModel clue) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.scaffoldBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppTheme.primaryLight,
                child: Text(
                  clue.user?.nickname.isNotEmpty == true ? clue.user!.nickname[0] : '?',
                  style: TextStyle(fontSize: 12, color: AppTheme.primaryColor),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                clue.user?.nickname ?? '匿名用户',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const Spacer(),
              Text(
                clue.createdAt.length > 16 ? clue.createdAt.substring(0, 16) : clue.createdAt,
                style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(clue.content, style: const TextStyle(fontSize: 14, height: 1.5)),
          if (clue.images.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: clue.images.map((url) => ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(url, width: 60, height: 60, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(width: 60, height: 60, color: Colors.grey[200]),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final auth = context.watch<AuthProvider>();
    final isOwner = auth.isLoggedIn && _post != null && auth.user?.id == _post!.userId;
    final canEdit = isOwner && _post!.canEdit;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2)),
          ],
        ),
        child: Row(
          children: [
            // 编辑按钮（仅发布者可见且状态可编辑）
            if (canEdit) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.pushNamed(
                      context, AppRoutes.postEdit, arguments: _post!,
                    );
                    if (result == true) _loadDetail();
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('编辑'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _callPhone,
                icon: const Icon(Icons.phone),
                label: Text(AppLocalizations.of(context)!.get('call')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClueSubmitPage(
                        postId: _post!.id,
                        postName: _post!.name,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.lightbulb_outline),
                label: Text(AppLocalizations.of(context)!.get('provide_clue')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _callPhone() async {
    final phone = _post?.contactPhone;
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    try {
      await launchUrl(uri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.get('call_failed'))),
        );
      }
    }
  }

  Future<void> _share() async {
    if (_post == null) return;
    // ⚠️ 儿童类分享时隐藏联系电话，引导通过平台联系
    final contactLine = _post!.isChild
        ? '联系方式：请通过平台查看'
        : '联系电话：${_post!.contactPhone}';
    final text = '【回家了么】寻找${_post!.categoryText}：${_post!.name}\n'
        '走失地点：${_post!.locationText}\n'
        '$contactLine\n'
        '请帮忙转发扩散，谢谢！';
    try {
      // iPad 需要 sharePositionOrigin 定位弹出框
      final box = context.findRenderObject() as RenderBox?;
      await Share.share(
        text,
        sharePositionOrigin: box != null
            ? Rect.fromLTWH(box.size.width - 50, 0, 50, 50)
            : null,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.get('share_failed'))),
        );
      }
    }
  }

  void _showReport() {
    showDialog(
      context: context,
      builder: (_) => ReportDialog(
        targetType: 1,
        targetId: widget.postId,
      ),
    );
  }
}
