/// 通知模型
class NotificationModel {
  final int id;
  final int userId;
  final int type;        // 1=线索回复 2=审核通过 3=审核驳回 4=举报处理 5=系统通知 6=举报违规
  final String title;
  final String content;
  final int? postId;     // 关联的启事ID
  final int isRead;      // 0=未读 1=已读
  final String createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    this.type = 5,
    required this.title,
    required this.content,
    this.postId,
    this.isRead = 0,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      type: json['type'] ?? 5,
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      postId: json['post_id'],
      isRead: json['is_read'] ?? 0,
      createdAt: json['created_at'] ?? '',
    );
  }

  bool get isUnread => isRead == 0;

  /// 通知类型图标
  String get typeLabel {
    switch (type) {
      case 1: return '消息回复';
      case 2: return '审核通过';
      case 3: return '审核驳回';
      case 4: return '举报处理';
      case 5: return '系统通知';
      case 6: return '举报违规';
      default: return '通知';
    }
  }
}
