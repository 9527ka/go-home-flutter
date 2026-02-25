/// 好友模型
class FriendModel {
  final int id; // 好友关系 ID
  final int userId; // 好友的用户 ID
  final String nickname;
  final String avatar;
  final String account;
  final String remark; // 好友备注
  final String createdAt;

  FriendModel({
    required this.id,
    required this.userId,
    required this.nickname,
    this.avatar = '',
    this.account = '',
    this.remark = '',
    this.createdAt = '',
  });

  factory FriendModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return FriendModel(
      id: json['id'] ?? 0,
      userId: json['friend_id'] ?? json['user_id'] ?? user?['id'] ?? 0,
      nickname: json['nickname'] ?? user?['nickname'] ?? '',
      avatar: json['avatar'] ?? user?['avatar'] ?? '',
      account: json['account'] ?? user?['account'] ?? '',
      remark: json['remark'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'nickname': nickname,
        'avatar': avatar,
        'account': account,
        'remark': remark,
        'created_at': createdAt,
      };

  /// 显示名称：优先备注，其次昵称
  String get displayName => remark.isNotEmpty ? remark : nickname;
}
