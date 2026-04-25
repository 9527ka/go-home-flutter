import 'vip.dart';

class FoundStoryModel {
  final int id;
  final int postId;
  final int userId;
  final String content;
  final List<String> images;
  final String? foundAt;
  final double rewardAmount;
  final bool isRewarded;
  final int status; // 0 待审 1 通过 2 驳回
  final String createdAt;

  // 嵌套（列表/详情）
  final String userNickname;
  final String userAvatar;
  final VipBadgeModel? userVip;
  final String postName;
  final int? postCategory;
  final String postLostCity;

  const FoundStoryModel({
    required this.id,
    required this.postId,
    required this.userId,
    this.content = '',
    this.images = const [],
    this.foundAt,
    this.rewardAmount = 0,
    this.isRewarded = false,
    this.status = 0,
    this.createdAt = '',
    this.userNickname = '',
    this.userAvatar = '',
    this.userVip,
    this.postName = '',
    this.postCategory,
    this.postLostCity = '',
  });

  factory FoundStoryModel.fromJson(Map<String, dynamic> json) {
    final rawImages = (json['images'] ?? '') as String;
    final imgs = rawImages.isEmpty
        ? const <String>[]
        : rawImages.split(',').where((e) => e.isNotEmpty).toList();
    final user = json['user'] as Map<String, dynamic>?;
    final post = json['post'] as Map<String, dynamic>?;
    return FoundStoryModel(
      id: json['id'] ?? 0,
      postId: json['post_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      content: json['content'] ?? '',
      images: imgs,
      foundAt: json['found_at'],
      rewardAmount: double.tryParse('${json['reward_amount']}') ?? 0,
      isRewarded: json['is_rewarded'] == true || json['is_rewarded'] == 1,
      status: (json['status'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] ?? '',
      userNickname: user?['nickname'] ?? '',
      userAvatar: user?['avatar'] ?? '',
      userVip: VipBadgeModel.tryParse(user?['vip']),
      postName: post?['name'] ?? '',
      postCategory: (post?['category'] as num?)?.toInt(),
      postLostCity: post?['lost_city'] ?? '',
    );
  }

  bool get isApproved => status == 1;
  bool get isPending  => status == 0;
  bool get isRejected => status == 2;
}
