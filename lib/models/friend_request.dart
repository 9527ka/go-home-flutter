/// 好友请求状态
enum FriendRequestStatus { pending, accepted, rejected }

/// 好友请求模型
class FriendRequestModel {
  final int id;
  final int fromId;
  final int toId;
  final String message;
  final FriendRequestStatus status;
  final String createdAt;
  // 发送者信息（用于列表展示）
  final String fromNickname;
  final String fromAvatar;

  FriendRequestModel({
    required this.id,
    required this.fromId,
    required this.toId,
    this.message = '',
    this.status = FriendRequestStatus.pending,
    this.createdAt = '',
    this.fromNickname = '',
    this.fromAvatar = '',
  });

  factory FriendRequestModel.fromJson(Map<String, dynamic> json) {
    final fromUser = json['from_user'] as Map<String, dynamic>?;
    return FriendRequestModel(
      id: json['id'] ?? 0,
      fromId: json['from_id'] ?? 0,
      toId: json['to_id'] ?? 0,
      message: json['message'] ?? '',
      status: _parseStatus(json['status']),
      createdAt: json['created_at'] ?? '',
      fromNickname: json['from_nickname'] ?? fromUser?['nickname'] ?? '',
      fromAvatar: json['from_avatar'] ?? fromUser?['avatar'] ?? '',
    );
  }

  static FriendRequestStatus _parseStatus(dynamic value) {
    if (value is int) {
      switch (value) {
        case 1:
          return FriendRequestStatus.accepted;
        case 2:
          return FriendRequestStatus.rejected;
        default:
          return FriendRequestStatus.pending;
      }
    }
    return FriendRequestStatus.pending;
  }
}
