/// 群组模型
class GroupModel {
  final int id;
  final String name;
  final String avatar;
  final String description;
  final String announcement;
  final int ownerId;
  final int maxMembers;
  final int memberCount;
  final int status; // 1=活跃 2=已解散
  final int banned; // 0=正常 1=被管理员封禁
  final int allMuted; // 0=正常 1=全员禁言
  final String createdAt;

  GroupModel({
    required this.id,
    required this.name,
    this.avatar = '',
    this.description = '',
    this.announcement = '',
    required this.ownerId,
    this.maxMembers = 100,
    this.memberCount = 1,
    this.status = 1,
    this.banned = 0,
    this.allMuted = 0,
    this.createdAt = '',
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      avatar: json['avatar'] ?? '',
      description: json['description'] ?? '',
      announcement: json['announcement'] ?? '',
      ownerId: json['owner_id'] ?? 0,
      maxMembers: json['max_members'] ?? 100,
      memberCount: json['member_count'] ?? 1,
      status: json['status'] ?? 1,
      banned: json['banned'] ?? 0,
      allMuted: json['all_muted'] ?? 0,
      createdAt: json['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar': avatar,
        'description': description,
        'announcement': announcement,
        'owner_id': ownerId,
        'max_members': maxMembers,
        'member_count': memberCount,
        'status': status,
        'banned': banned,
        'all_muted': allMuted,
        'created_at': createdAt,
      };

  GroupModel copyWith({
    int? id,
    String? name,
    String? avatar,
    String? description,
    String? announcement,
    int? ownerId,
    int? maxMembers,
    int? memberCount,
    int? status,
    int? banned,
    int? allMuted,
    String? createdAt,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      description: description ?? this.description,
      announcement: announcement ?? this.announcement,
      ownerId: ownerId ?? this.ownerId,
      maxMembers: maxMembers ?? this.maxMembers,
      memberCount: memberCount ?? this.memberCount,
      status: status ?? this.status,
      banned: banned ?? this.banned,
      allMuted: allMuted ?? this.allMuted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isActive => status == 1;

  /// 是否是公共聊天室（id=1）
  bool get isPublicRoom => id == 1;

  /// 是否被管理员封禁
  bool get isBanned => banned == 1;

  /// 是否全员禁言
  bool get isAllMuted => allMuted == 1;
}
