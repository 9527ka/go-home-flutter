import 'vip.dart';

/// 好友模型
class FriendModel {
  final int id; // 好友关系 ID
  final int userId; // 好友的用户 ID
  final String nickname;
  final String avatar;
  final String account;
  final String userCode;
  final String remark; // 好友备注
  final String createdAt;
  final int userType; // 0=普通用户 1=官方客服
  final VipBadgeModel? vip;

  FriendModel({
    required this.id,
    required this.userId,
    required this.nickname,
    this.avatar = '',
    this.account = '',
    this.userCode = '',
    this.remark = '',
    this.createdAt = '',
    this.userType = 0,
    this.vip,
  });

  factory FriendModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final friend = json['friend'] as Map<String, dynamic>?;
    // 兼容多种 API 返回格式：顶层字段 / user 子对象 / friend 子对象
    return FriendModel(
      id: json['id'] ?? 0,
      userId: json['friend_id'] ?? json['user_id'] ?? user?['id'] ?? friend?['id'] ?? 0,
      nickname: json['nickname'] ?? user?['nickname'] ?? friend?['nickname'] ?? '',
      avatar: json['avatar'] ?? user?['avatar'] ?? friend?['avatar'] ?? '',
      account: json['account'] ?? user?['account'] ?? friend?['account'] ?? '',
      userCode: json['user_code'] ?? user?['user_code'] ?? friend?['user_code'] ?? '',
      remark: json['remark'] ?? '',
      createdAt: json['created_at'] ?? '',
      userType: json['user_type'] ?? user?['user_type'] ?? friend?['user_type'] ?? 0,
      vip: VipBadgeModel.tryParse(json['vip'])
          ?? VipBadgeModel.tryParse(user?['vip'])
          ?? VipBadgeModel.tryParse(friend?['vip']),
    );
  }

  bool get isOfficialService => userType == 1;

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'nickname': nickname,
        'avatar': avatar,
        'account': account,
        'user_code': userCode,
        'remark': remark,
        'created_at': createdAt,
        'user_type': userType,
      };

  /// 显示名称：优先备注，其次昵称
  String get displayName => remark.isNotEmpty ? remark : nickname;
}
