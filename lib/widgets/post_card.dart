import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/api.dart';
import '../config/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/post.dart';
import 'report_dialog.dart';

class PostCard extends StatelessWidget {
  final PostModel post;
  final VoidCallback? onTap;

  const PostCard({super.key, required this.post, this.onTap});

  @override
  Widget build(BuildContext context) {
    final catColor = AppTheme.getCategoryColor(post.category);
    final catBgColor = AppTheme.getCategoryBgColor(post.category);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== 顶部：分类色带 =====
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: catColor.withOpacity(0.6),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===== 左：封面图 =====
                  _buildCover(catColor),
                  const SizedBox(width: 14),

                  // ===== 右：信息 =====
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 分类标签 + 置顶标识 + 名字
                        Row(
                          children: [
                            _buildCategoryTag(catColor, catBgColor),
                            if (post.isBoosted) ...[
                              const SizedBox(width: 6),
                              _buildBoostBadge(context),
                            ],
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                post.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // 特征摘要
                        Text(
                          post.appearance,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                              height: 1.4),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 10),

                        // 地点 + 时间
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 14, color: catColor.withOpacity(0.7)),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                post.locationText.isNotEmpty
                                    ? post.locationText
                                    : '未知位置',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatTime(post.createdAt),
                              style: TextStyle(
                                  fontSize: 11, color: AppTheme.textHint),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // 底部统计栏
                        Row(
                          children: [
                            _statChip(Icons.favorite_border, post.likeCount, color: post.likeCount > 0 ? const Color(0xFFE74C3C) : null),
                            const SizedBox(width: 12),
                            _statChip(Icons.lightbulb_outline, post.clueCount),
                            const SizedBox(width: 12),
                            _statChip(Icons.remove_red_eye_outlined, post.viewCount),
                            const Spacer(),
                            // 举报按钮
                            GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => ReportDialog(
                                    targetType: 1, // 1=启事
                                    targetId: post.id,
                                  ),
                                );
                              },
                              child: const Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: Icon(
                                  Icons.more_horiz,
                                  size: 18,
                                  color: AppTheme.textHint,
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
          ],
        ),
      ),
    );
  }

  Widget _buildCover(Color catColor) {
    final imageUrl = post.coverImage;

    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: AppTheme.getCategoryBgColor(post.category),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: imageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) {
                  return Center(
                    child: Icon(AppTheme.getCategoryIcon(post.category),
                        color: catColor.withOpacity(0.4), size: 32),
                  );
                },
                errorWidget: (context, url, error) {
                  return Center(
                    child: Icon(Icons.broken_image_outlined,
                        color: AppTheme.textHint, size: 28),
                  );
                },
              )
            : Center(
                child: Icon(AppTheme.getCategoryIcon(post.category),
                    size: 36, color: catColor.withOpacity(0.4)),
              ),
      ),
    );
  }

  Widget _buildBoostBadge(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFFF8F00)],
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.rocket_launch, size: 10, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            l10n.get('boosted'),
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTag(Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppTheme.getCategoryIcon(post.category), size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            post.categoryText,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, int count, {Color? color}) {
    final c = color ?? AppTheme.textHint;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c.withOpacity(0.7)),
        const SizedBox(width: 3),
        Text(
          count > 9999 ? '${(count / 10000).toStringAsFixed(1)}w' : (count > 999 ? '999+' : '$count'),
          style: TextStyle(fontSize: 12, color: c.withOpacity(0.7)),
        ),
      ],
    );
  }

  String _formatTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return '刚刚';
      if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
      if (diff.inHours < 24) return '${diff.inHours}小时前';
      if (diff.inDays < 7) return '${diff.inDays}天前';
      if (diff.inDays < 365) return '${date.month}月${date.day}日';
      return '${date.year}/${date.month}/${date.day}';
    } catch (e) {
      return dateStr;
    }
  }
}
