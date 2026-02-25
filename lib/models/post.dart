import 'user.dart';

class PostModel {
  final int id;
  final int userId;
  final int category;
  final String categoryText;
  final String name;
  final int gender;
  final String age;
  final String species;
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
  final String createdAt;
  final List<PostImageModel> images;
  final List<ClueModel> clues;
  final UserModel? user;
  final String? disclaimer;
  final String? auditRemark;

  PostModel({
    required this.id,
    required this.userId,
    required this.category,
    this.categoryText = '',
    required this.name,
    this.gender = 0,
    this.age = '',
    this.species = '',
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
    required this.createdAt,
    this.images = const [],
    this.clues = const [],
    this.user,
    this.disclaimer,
    this.auditRemark,
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

    return PostModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      category: json['category'] ?? 0,
      categoryText: json['category_text'] ?? '',
      name: json['name'] ?? '',
      gender: json['gender'] ?? 0,
      age: json['age'] ?? '',
      species: json['species'] ?? '',
      appearance: json['appearance'] ?? '',
      description: json['description'] ?? '',
      lostAt: json['lost_at'] ?? '',
      lostProvince: json['lost_province'] ?? '',
      lostCity: json['lost_city'] ?? '',
      lostDistrict: json['lost_district'] ?? '',
      lostAddress: json['lost_address'] ?? '',
      lostLongitude: json['lost_longitude']?.toDouble(),
      lostLatitude: json['lost_latitude']?.toDouble(),
      contactName: json['contact_name'] ?? '',
      contactPhone: json['contact_phone'] ?? '',
      status: json['status'] ?? 0,
      statusText: json['status_text'] ?? '',
      viewCount: json['view_count'] ?? 0,
      clueCount: json['clue_count'] ?? 0,
      shareCount: json['share_count'] ?? 0,
      createdAt: json['created_at'] ?? '',
      images: imageList,
      clues: clueList,
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
      disclaimer: json['disclaimer'],
      auditRemark: json['audit_remark'],
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

  /// 是否为儿童类别
  bool get isChild => category == 3;

  /// 是否可编辑（待审核或被驳回）
  bool get canEdit => status == 0 || status == 4;
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

  factory PostImageModel.fromJson(Map<String, dynamic> json) {
    return PostImageModel(
      id: json['id'] ?? 0,
      imageUrl: json['image_url'] ?? '',
      thumbUrl: json['thumb_url'] ?? '',
      sortOrder: json['sort_order'] ?? 0,
    );
  }
}
