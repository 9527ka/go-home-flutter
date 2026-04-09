import 'user.dart';

class CommentModel {
  final int id;
  final int postId;
  final int userId;
  final int? parentId;
  final int? replyToUserId;
  final String content;
  final int likeCount;
  final int replyCount;
  final int status;
  final String createdAt;
  final UserModel? user;
  final UserModel? replyToUser;
  final List<CommentModel> replyPreview;
  final bool isLiked;

  CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    this.parentId,
    this.replyToUserId,
    required this.content,
    this.likeCount = 0,
    this.replyCount = 0,
    this.status = 1,
    required this.createdAt,
    this.user,
    this.replyToUser,
    this.replyPreview = const [],
    this.isLiked = false,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    List<CommentModel> previews = [];
    if (json['reply_preview'] != null) {
      previews = (json['reply_preview'] as List)
          .map((r) => CommentModel.fromJson(r))
          .toList();
    }

    return CommentModel(
      id: json['id'] ?? 0,
      postId: json['post_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      parentId: json['parent_id'],
      replyToUserId: json['reply_to_user_id'],
      content: json['content'] ?? '',
      likeCount: json['like_count'] ?? 0,
      replyCount: json['reply_count'] ?? 0,
      status: json['status'] ?? 1,
      createdAt: json['created_at'] ?? '',
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
      replyToUser: json['reply_to_user'] != null
          ? UserModel.fromJson(json['reply_to_user'])
          : null,
      replyPreview: previews,
      isLiked: json['is_liked'] == true || json['is_liked'] == 1,
    );
  }

  /// 显示时间（简化格式）
  String get displayTime {
    if (createdAt.length > 16) return createdAt.substring(0, 16);
    return createdAt;
  }
}
