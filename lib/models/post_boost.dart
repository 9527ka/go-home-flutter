import 'user.dart';

/// 启事置顶/推广记录
class PostBoostModel {
  final int id;
  final int userId;
  final int postId;
  final int hours;
  final double totalCost;
  final double hourlyRate;
  final String startAt;
  final String expireAt;
  final int status; // 1=活跃 2=过期 3=取消
  final UserModel? user;

  PostBoostModel({
    required this.id,
    this.userId = 0,
    this.postId = 0,
    this.hours = 0,
    this.totalCost = 0,
    this.hourlyRate = 0,
    this.startAt = '',
    this.expireAt = '',
    this.status = 1,
    this.user,
  });

  factory PostBoostModel.fromJson(Map<String, dynamic> json) {
    return PostBoostModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      postId: json['post_id'] ?? 0,
      hours: int.tryParse('${json['hours']}') ?? 0,
      totalCost: double.tryParse('${json['total_cost']}') ?? 0,
      hourlyRate: double.tryParse('${json['hourly_rate']}') ?? 0,
      startAt: json['start_at'] ?? '',
      expireAt: json['expire_at'] ?? '',
      status: json['status'] ?? 1,
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
    );
  }

  bool get isActive => status == 1;
}
