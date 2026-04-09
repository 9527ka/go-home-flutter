import 'user.dart';

/// 捐赠记录
class DonationModel {
  final int id;
  final int fromUserId;
  final int toUserId;
  final int postId;
  final double amount;
  final String message;
  final bool isAnonymous;
  final String createdAt;
  final UserModel? fromUser;
  final UserModel? toUser;

  DonationModel({
    required this.id,
    this.fromUserId = 0,
    this.toUserId = 0,
    this.postId = 0,
    required this.amount,
    this.message = '',
    this.isAnonymous = false,
    required this.createdAt,
    this.fromUser,
    this.toUser,
  });

  factory DonationModel.fromJson(Map<String, dynamic> json) {
    return DonationModel(
      id: json['id'] ?? 0,
      fromUserId: json['from_user_id'] ?? 0,
      toUserId: json['to_user_id'] ?? 0,
      postId: json['post_id'] ?? 0,
      amount: double.tryParse('${json['amount']}') ?? 0,
      message: json['message'] ?? '',
      isAnonymous: json['is_anonymous'] == 1 || json['is_anonymous'] == true,
      createdAt: json['created_at'] ?? '',
      fromUser: json['from_user'] != null ? UserModel.fromJson(json['from_user']) : null,
      toUser: json['to_user'] != null ? UserModel.fromJson(json['to_user']) : null,
    );
  }
}
