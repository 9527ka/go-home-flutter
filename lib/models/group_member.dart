/// 群成员角色
enum GroupMemberRole { member, admin, owner }

/// 群成员模型
class GroupMemberModel {
  final int id;
  final int groupId;
  final int userId;
  final GroupMemberRole role;
  final String joinedAt;
  // 关联用户信息（后端 detail 接口已扁平化到顶层）
  final String userNickname;
  final String userAvatar;
  final String userCode;

  GroupMemberModel({
    required this.id,
    required this.groupId,
    required this.userId,
    this.role = GroupMemberRole.member,
    this.joinedAt = '',
    this.userNickname = '',
    this.userAvatar = '',
    this.userCode = '',
  });

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) {
    // 后端可能以嵌套 user 对象返回，也可能扁平化到顶层
    final user = json['user'] as Map<String, dynamic>?;
    return GroupMemberModel(
      id: json['id'] ?? 0,
      groupId: json['group_id'] ?? 0,
      userId: json['user_id'] ?? user?['id'] ?? 0,
      role: _parseRole(json['role']),
      joinedAt: json['joined_at'] ?? '',
      userNickname: json['nickname'] ?? user?['nickname'] ?? '',
      userAvatar: json['avatar'] ?? user?['avatar'] ?? '',
      userCode: json['user_code'] ?? user?['user_code'] ?? '',
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

  /// 显示名称
  String get displayName => userNickname;

  bool get isOwner => role == GroupMemberRole.owner;
  bool get isAdmin => role == GroupMemberRole.admin || role == GroupMemberRole.owner;
}
