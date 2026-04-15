import 'user.dart';

/// 悬赏发放记录
class RewardClaimModel {
  final int id;
  final int postId;
  final int clueId;
  final int fromUserId;
  final int toUserId;
  final double amount;
  final String message;
  final String createdAt;
  final UserModel? toUser;

  RewardClaimModel({
    required this.id,
    this.postId = 0,
    this.clueId = 0,
    this.fromUserId = 0,
    this.toUserId = 0,
    required this.amount,
    this.message = '',
    required this.createdAt,
    this.toUser,
  });

  factory RewardClaimModel.fromJson(Map<String, dynamic> json) {
    return RewardClaimModel(
      id: json['id'] ?? 0,
      postId: json['post_id'] ?? 0,
      clueId: json['clue_id'] ?? 0,
      fromUserId: json['from_user_id'] ?? 0,
      toUserId: json['to_user_id'] ?? 0,
      amount: double.tryParse('${json['amount']}') ?? 0,
      message: json['message'] ?? '',
      createdAt: json['created_at'] ?? '',
      toUser: json['to_user'] != null ? UserModel.fromJson(json['to_user']) : null,
    );
  }
}
