import 'donation.dart';
import 'post_boost.dart';
import 'reward_claim.dart';
import 'user.dart';

class PostModel {
  final int id;
  final int userId;
  final int category;
  final String categoryText;
  final String name;
  final int gender;
  final String age;
  final String appearance;
  final String description;
  final String lostAt;
  final String lostProvince;
  final String lostCity;
  final String lostDistrict;
  final String lostAddress;
  final double? lostLongitude;
  final double? lostLatitude;
  final String contactName;
  final String contactPhone;
  final int status;
  final String statusText;
  final int viewCount;
  final int clueCount;
  final int shareCount;
  final int likeCount;
  final int commentCount;
  final String createdAt;
  final List<PostImageModel> images;
  final List<ClueModel> clues;
  final UserModel? user;
  final int visibility; // 1=公开 2=仅自己可见
  final String? disclaimer;
  final String? auditRemark;
  final bool isBoosted;
  final double rewardAmount;
  final double rewardPaid;
  final bool isLiked;
  final bool isFavorited;
  final List<DonationModel> donations;
  final List<PostBoostModel> boosts;
  final List<RewardClaimModel> rewardClaims;

  PostModel({
    required this.id,
    required this.userId,
    required this.category,
    this.categoryText = '',
    required this.name,
    this.gender = 0,
    this.age = '',
    required this.appearance,
    this.description = '',
    required this.lostAt,
    this.lostProvince = '',
    this.lostCity = '',
    this.lostDistrict = '',
    this.lostAddress = '',
    this.lostLongitude,
    this.lostLatitude,
    this.contactName = '',
    required this.contactPhone,
    this.status = 0,
    this.statusText = '',
    this.viewCount = 0,
    this.clueCount = 0,
    this.shareCount = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    required this.createdAt,
    this.images = const [],
    this.clues = const [],
    this.visibility = 1,
    this.user,
    this.disclaimer,
    this.auditRemark,
    this.rewardAmount = 0.0,
    this.rewardPaid = 0.0,
    this.isBoosted = false,
    this.isLiked = false,
    this.isFavorited = false,
    this.donations = const [],
    this.boosts = const [],
    this.rewardClaims = const [],
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    List<PostImageModel> imageList = [];
    if (json['images'] != null) {
      imageList = (json['images'] as List)
          .map((i) => PostImageModel.fromJson(i))
          .toList();
    }

    List<ClueModel> clueList = [];
    if (json['clues'] != null) {
      clueList = (json['clues'] as List)
          .map((c) => ClueModel.fromJson(c))
          .toList();
    }

    List<DonationModel> donationList = [];
    try {
      if (json['donations'] != null) {
        donationList = (json['donations'] as List)
            .map((d) => DonationModel.fromJson(d as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    List<PostBoostModel> boostList = [];
    try {
      if (json['boosts'] != null) {
        boostList = (json['boosts'] as List)
            .map((b) => PostBoostModel.fromJson(b as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    List<RewardClaimModel> rewardClaimList = [];
    try {
      if (json['reward_claims'] != null) {
        rewardClaimList = (json['reward_claims'] as List)
            .map((r) => RewardClaimModel.fromJson(r as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    return PostModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      category: json['category'] ?? 0,
      categoryText: json['category_text'] ?? '',
      name: json['name'] ?? '',
      gender: json['gender'] ?? 0,
      age: json['age'] ?? '',
      appearance: json['appearance'] ?? '',
      description: json['description'] ?? '',
      lostAt: json['lost_at'] ?? '',
      lostProvince: json['lost_province'] ?? '',
      lostCity: json['lost_city'] ?? '',
      lostDistrict: json['lost_district'] ?? '',
      lostAddress: json['lost_address'] ?? '',
      lostLongitude: json['lost_longitude'] != null ? double.tryParse('${json['lost_longitude']}') : null,
      lostLatitude: json['lost_latitude'] != null ? double.tryParse('${json['lost_latitude']}') : null,
      contactName: json['contact_name'] ?? '',
      contactPhone: json['contact_phone'] ?? '',
      status: json['status'] ?? 0,
      statusText: json['status_text'] ?? '',
      viewCount: json['view_count'] ?? 0,
      clueCount: json['clue_count'] ?? 0,
      shareCount: json['share_count'] ?? 0,
      likeCount: json['like_count'] ?? 0,
      commentCount: json['comment_count'] ?? 0,
      createdAt: json['created_at'] ?? '',
      visibility: json['visibility'] ?? 1,
      images: imageList,
      clues: clueList,
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
      disclaimer: json['disclaimer'],
      auditRemark: json['audit_remark'],
      rewardAmount: double.tryParse('${json['reward_amount']}') ?? 0.0,
      rewardPaid: double.tryParse('${json['reward_paid']}') ?? 0.0,
      isBoosted: json['is_boosted'] == 1 || json['is_boosted'] == true,
      isLiked: json['is_liked'] == true || json['is_liked'] == 1,
      isFavorited: json['is_favorited'] == true || json['is_favorited'] == 1,
      donations: donationList,
      boosts: boostList,
      rewardClaims: rewardClaimList,
    );
  }

  PostModel copyWith({
    bool? isLiked,
    bool? isFavorited,

    int? likeCount,
    int? commentCount,
  }) {
    return PostModel(
      id: id,
      userId: userId,
      category: category,
      categoryText: categoryText,
      name: name,
      gender: gender,
      age: age,
      appearance: appearance,
      description: description,
      lostAt: lostAt,
      lostProvince: lostProvince,
      lostCity: lostCity,
      lostDistrict: lostDistrict,
      lostAddress: lostAddress,
      lostLongitude: lostLongitude,
      lostLatitude: lostLatitude,
      contactName: contactName,
      contactPhone: contactPhone,
      status: status,
      statusText: statusText,
      viewCount: viewCount,
      clueCount: clueCount,
      shareCount: shareCount,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt,
      visibility: visibility,
      images: images,
      clues: clues,
      user: user,
      disclaimer: disclaimer,
      auditRemark: auditRemark,
      rewardAmount: rewardAmount,
      rewardPaid: rewardPaid,
      isBoosted: isBoosted,
      isLiked: isLiked ?? this.isLiked,
      isFavorited: isFavorited ?? this.isFavorited,
      donations: donations,
      boosts: boosts,
      rewardClaims: rewardClaims,
    );
  }

  /// 封面图
  String get coverImage {
    if (images.isNotEmpty) {
      return images.first.thumbUrl.isNotEmpty
          ? images.first.thumbUrl
          : images.first.imageUrl;
    }
    return '';
  }

  /// 位置描述
  String get locationText {
    final parts = [lostProvince, lostCity, lostDistrict, lostAddress];
    return parts.where((p) => p.isNotEmpty).join(' ');
  }

  /// 性别文本
  String get genderText {
    switch (gender) {
      case 1:
        return category == 1 ? '公' : '男';
      case 2:
        return category == 1 ? '母' : '女';
      default:
        return '未知';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'category': category,
    'category_text': categoryText,
    'name': name,
    'gender': gender,
    'age': age,
    'appearance': appearance,
    'description': description,
    'lost_at': lostAt,
    'lost_province': lostProvince,
    'lost_city': lostCity,
    'lost_district': lostDistrict,
    'lost_address': lostAddress,
    'lost_longitude': lostLongitude,
    'lost_latitude': lostLatitude,
    'contact_name': contactName,
    'contact_phone': contactPhone,
    'status': status,
    'status_text': statusText,
    'view_count': viewCount,
    'clue_count': clueCount,
    'share_count': shareCount,
    'like_count': likeCount,
    'comment_count': commentCount,
    'created_at': createdAt,
    'visibility': visibility,
    'images': images.map((i) => i.toJson()).toList(),
    'clues': clues.map((c) => c.toJson()).toList(),
    'user': user?.toJson(),
    'disclaimer': disclaimer,
    'audit_remark': auditRemark,
    'is_boosted': isBoosted ? 1 : 0,
    'reward_amount': rewardAmount,
    'reward_paid': rewardPaid,
  };

  /// 是否有悬赏
  bool get hasReward => rewardAmount > 0;

  /// 剩余可发放悬赏
  double get rewardRemaining => rewardAmount - rewardPaid;

  /// 是否可编辑（待审核、被驳回、举报屏蔽）
  bool get canEdit => status == 0 || status == 4 || status == 5;
}

class ClueModel {
  final int id;
  final int postId;
  final int userId;
  final String content;
  final List<String> images;
  final String? contactPhone;
  final String createdAt;
  final UserModel? user;

  ClueModel({
    required this.id,
    this.postId = 0,
    this.userId = 0,
    required this.content,
    this.images = const [],
    this.contactPhone,
    required this.createdAt,
    this.user,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'post_id': postId,
    'user_id': userId,
    'content': content,
    'images': images,
    'contact_phone': contactPhone,
    'created_at': createdAt,
    'user': user?.toJson(),
  };

  factory ClueModel.fromJson(Map<String, dynamic> json) {
    List<String> imageList = [];
    if (json['images'] != null) {
      if (json['images'] is List) {
        imageList = (json['images'] as List).map((e) => e.toString()).toList();
      } else if (json['images'] is String && (json['images'] as String).isNotEmpty) {
        imageList = (json['images'] as String).split(',');
      }
    }

    return ClueModel(
      id: json['id'] ?? 0,
      postId: json['post_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      content: json['content'] ?? '',
      images: imageList,
      contactPhone: json['contact_phone'],
      createdAt: json['created_at'] ?? '',
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
    );
  }
}

class PostImageModel {
  final int id;
  final String imageUrl;
  final String thumbUrl;
  final int sortOrder;

  PostImageModel({
    this.id = 0,
    required this.imageUrl,
    this.thumbUrl = '',
    this.sortOrder = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'image_url': imageUrl,
    'thumb_url': thumbUrl,
    'sort_order': sortOrder,
  };

  factory PostImageModel.fromJson(Map<String, dynamic> json) {
    return PostImageModel(
      id: json['id'] ?? 0,
      imageUrl: json['image_url'] ?? '',
      thumbUrl: json['thumb_url'] ?? '',
      sortOrder: json['sort_order'] ?? 0,
    );
  }
}
