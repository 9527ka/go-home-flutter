import 'user.dart';

/// 安全地将 String / num / null 转为 double
double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

/// 红包
class RedPacketModel {
  final int id;
  final int userId;
  final int targetType; // 1=公共 2=私聊 3=群聊
  final int targetId;
  final double totalAmount;
  final int totalCount;
  final double remainingAmount;
  final int remainingCount;
  final String greeting;
  final int status; // 1=活跃 2=已领完 3=已过期
  final String? expireAt;
  final String createdAt;
  final UserModel? user;
  final List<RedPacketClaimModel> claims;

  // 详情接口附加字段
  final RedPacketClaimModel? myClaim;
  final int? bestUserId;

  RedPacketModel({
    required this.id,
    this.userId = 0,
    this.targetType = 1,
    this.targetId = 0,
    this.totalAmount = 0,
    this.totalCount = 0,
    this.remainingAmount = 0,
    this.remainingCount = 0,
    this.greeting = '',
    this.status = 1,
    this.expireAt,
    this.createdAt = '',
    this.user,
    this.claims = const [],
    this.myClaim,
    this.bestUserId,
  });

  factory RedPacketModel.fromJson(Map<String, dynamic> json) {
    List<RedPacketClaimModel> claimList = [];
    if (json['claims'] != null) {
      claimList = (json['claims'] as List)
          .map((c) => RedPacketClaimModel.fromJson(c))
          .toList();
    }

    return RedPacketModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      targetType: json['target_type'] ?? 1,
      targetId: json['target_id'] ?? 0,
      totalAmount: _toDouble(json['total_amount']),
      totalCount: json['total_count'] ?? 0,
      remainingAmount: _toDouble(json['remaining_amount']),
      remainingCount: json['remaining_count'] ?? 0,
      greeting: json['greeting'] ?? '',
      status: json['status'] ?? 1,
      expireAt: json['expire_at'],
      createdAt: json['created_at'] ?? '',
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
      claims: claimList,
      myClaim: json['my_claim'] != null
          ? RedPacketClaimModel.fromJson(json['my_claim'])
          : null,
      bestUserId: json['best_user_id'],
    );
  }

  bool get isActive => status == 1;
  bool get isFinished => status == 2;
  bool get isExpired => status == 3;
  bool get hasClaimed => myClaim != null;
  int get claimedCount => totalCount - remainingCount;
  double get claimedAmount => totalAmount - remainingAmount;
}

/// 红包领取记录
class RedPacketClaimModel {
  final int id;
  final int redPacketId;
  final int userId;
  final double amount;
  final String createdAt;
  final UserModel? user;

  RedPacketClaimModel({
    required this.id,
    this.redPacketId = 0,
    this.userId = 0,
    required this.amount,
    this.createdAt = '',
    this.user,
  });

  factory RedPacketClaimModel.fromJson(Map<String, dynamic> json) {
    return RedPacketClaimModel(
      id: json['id'] ?? 0,
      redPacketId: json['red_packet_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      amount: _toDouble(json['amount']),
      createdAt: json['created_at'] ?? '',
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
    );
  }
}
