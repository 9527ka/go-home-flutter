import 'package:flutter/material.dart';
import '../services/like_service.dart';

class InteractionProvider extends ChangeNotifier {
  final LikeService _likeService = LikeService();

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  // ==================== 点赞 ====================

  final Map<int, bool> _postLikeStatus = {};
  final Map<int, int> _postLikeCounts = {};

  bool isPostLiked(int postId) => _postLikeStatus[postId] ?? false;
  int postLikeCount(int postId) => _postLikeCounts[postId] ?? 0;

  void initPostLikeState(int postId, bool isLiked, int likeCount) {
    _postLikeStatus[postId] = isLiked;
    _postLikeCounts[postId] = likeCount;
  }

  /// 点赞/取消点赞帖子（乐观更新）
  Future<bool> togglePostLike(int postId) async {
    final wasLiked = _postLikeStatus[postId] ?? false;
    final oldCount = _postLikeCounts[postId] ?? 0;

    // 乐观更新
    _postLikeStatus[postId] = !wasLiked;
    _postLikeCounts[postId] = oldCount + (wasLiked ? -1 : 1);
    _safeNotify();

    try {
      final res = await _likeService.toggle(targetType: 1, targetId: postId);
      if (res['code'] == 0 && res['data'] != null) {
        _postLikeStatus[postId] = res['data']['is_liked'] == true;
        _postLikeCounts[postId] = res['data']['like_count'] ?? 0;
        _safeNotify();
        return true;
      }
      // API 失败，回滚到原始值
      _postLikeStatus[postId] = wasLiked;
      _postLikeCounts[postId] = oldCount;
      _safeNotify();
      return false;
    } catch (e) {
      _postLikeStatus[postId] = wasLiked;
      _postLikeCounts[postId] = oldCount;
      _safeNotify();
      return false;
    }
  }

  /// 点赞/取消点赞评论
  Future<Map<String, dynamic>?> toggleCommentLike(int commentId) async {
    try {
      final res = await _likeService.toggle(targetType: 2, targetId: commentId);
      if (res['code'] == 0 && res['data'] != null) {
        return {
          'is_liked': res['data']['is_liked'] == true,
          'like_count': res['data']['like_count'] ?? 0,
        };
      }
    } catch (e) {
      // 失败
    }
    return null;
  }

  /// 清理（登出时调用）
  void clear() {
    _postLikeStatus.clear();
    _postLikeCounts.clear();
    _safeNotify();
  }
}
