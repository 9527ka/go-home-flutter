import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// Interaction bar with like, share, and bookmark buttons.
class PostInteractionBar extends StatelessWidget {
  final bool isLiked;
  final int likeCount;
  final int shareCount;
  final bool isFavorited;
  final VoidCallback onLike;
  final VoidCallback onShare;
  final VoidCallback onFavorite;

  const PostInteractionBar({
    super.key,
    required this.isLiked,
    required this.likeCount,
    required this.shareCount,
    required this.isFavorited,
    required this.onLike,
    required this.onShare,
    required this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppTheme.dividerColor.withOpacity(0.5)),
          bottom: BorderSide(color: AppTheme.dividerColor.withOpacity(0.5)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _interactionButton(
            icon: isLiked ? Icons.favorite : Icons.favorite_border,
            label: _formatCount(likeCount),
            color: isLiked ? AppTheme.dangerColor : AppTheme.textSecondary,
            onTap: onLike,
          ),
          _interactionButton(
            icon: Icons.share_outlined,
            label: _formatCount(shareCount),
            color: AppTheme.textSecondary,
            onTap: onShare,
          ),
          _interactionButton(
            icon: isFavorited ? Icons.bookmark : Icons.bookmark_border,
            label: '收藏',
            color: isFavorited ? AppTheme.primaryColor : AppTheme.textSecondary,
            onTap: onFavorite,
          ),
        ],
      ),
    );
  }

  Widget _interactionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count <= 0) return '0';
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}w';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }
}
