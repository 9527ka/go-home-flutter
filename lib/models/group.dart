/// 群组模型
class GroupModel {
  final int id;
  final String name;
  final String avatar;
  final String description;
  final int ownerId;
  final int maxMembers;
  final int memberCount;
  final int status; // 1=活跃 2=已解散
  final String createdAt;

  GroupModel({
    required this.id,
    required this.name,
    this.avatar = '',
    this.description = '',
    required this.ownerId,
    this.maxMembers = 100,
    this.memberCount = 1,
    this.status = 1,
    this.createdAt = '',
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      avatar: json['avatar'] ?? '',
      description: json['description'] ?? '',
      ownerId: json['owner_id'] ?? 0,
      maxMembers: json['max_members'] ?? 100,
      memberCount: json['member_count'] ?? 1,
      status: json['status'] ?? 1,
      createdAt: json['created_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar': avatar,
        'description': description,
        'owner_id': ownerId,
        'max_members': maxMembers,
        'member_count': memberCount,
        'status': status,
        'created_at': createdAt,
      };

  bool get isActive => status == 1;
}
