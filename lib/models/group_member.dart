/// 群成员角色
enum GroupMemberRole { member, admin, owner }

/// 群成员模型
class GroupMemberModel {
  final int id;
  final int groupId;
  final int userId;
  final GroupMemberRole role;
  final String nickname; // 群内昵称
  final bool muted;
  final String joinedAt;
  // 关联用户信息
  final String userNickname;
  final String userAvatar;

  GroupMemberModel({
    required this.id,
    required this.groupId,
    required this.userId,
    this.role = GroupMemberRole.member,
    this.nickname = '',
    this.muted = false,
    this.joinedAt = '',
    this.userNickname = '',
    this.userAvatar = '',
  });

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return GroupMemberModel(
      id: json['id'] ?? 0,
      groupId: json['group_id'] ?? 0,
      userId: json['user_id'] ?? user?['id'] ?? 0,
      role: _parseRole(json['role']),
      nickname: json['nickname'] ?? '',
      muted: json['muted'] == 1 || json['muted'] == true,
      joinedAt: json['joined_at'] ?? '',
      userNickname: json['user_nickname'] ?? user?['nickname'] ?? '',
      userAvatar: json['user_avatar'] ?? user?['avatar'] ?? '',
    );
  }

  static GroupMemberRole _parseRole(dynamic value) {
    if (value is int) {
      switch (value) {
        case 1:
          return GroupMemberRole.admin;
        case 2:
          return GroupMemberRole.owner;
        default:
          return GroupMemberRole.member;
      }
    }
    return GroupMemberRole.member;
  }

  /// 显示名称：优先群昵称，其次用户昵称
  String get displayName => nickname.isNotEmpty ? nickname : userNickname;

  bool get isOwner => role == GroupMemberRole.owner;
  bool get isAdmin => role == GroupMemberRole.admin || role == GroupMemberRole.owner;
}
