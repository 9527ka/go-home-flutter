import '../config/api.dart';
import '../models/api_response.dart';
import '../models/post.dart';
import 'http_client.dart';

class PostService {
  final _http = HttpClient();

  /// 创建启事
  Future<Map<String, dynamic>> create({
    required int category,
    required String name,
    required String appearance,
    String description = '',
    required String lostAt,
    String lostProvince = '',
    required String lostCity,
    String lostDistrict = '',
    String lostAddress = '',
    double? lostLongitude,
    double? lostLatitude,
    List<String> images = const [],
    int visibility = 1,
    double? rewardAmount,
  }) async {
    return await _http.post(ApiConfig.postCreate, data: {
      'category': category,
      'name': name,
      'appearance': appearance,
      'description': description,
      'lost_at': lostAt,
      'lost_province': lostProvince,
      'lost_city': lostCity,
      'lost_district': lostDistrict,
      'lost_address': lostAddress,
      'lost_longitude': lostLongitude,
      'lost_latitude': lostLatitude,
      'images': images,
      'visibility': visibility,
      if (rewardAmount != null && rewardAmount > 0) 'reward_amount': rewardAmount,
    });
  }

  /// 获取列表
  /// category 支持单个数字 "2" 或逗号分隔 "1,4"
  Future<PageData<PostModel>> getList({
    int page = 1,
    int pageSize = 20,
    String? category,
    String? city,
    String? keyword,
    int? days,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (category != null && category.isNotEmpty) params['category'] = category;
    if (city != null && city.isNotEmpty) params['city'] = city;
    if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;
    if (days != null) params['days'] = days;

    final res = await _http.get(ApiConfig.postList, params: params);

    if (res['code'] == 0 && res['data'] != null) {
      return PageData.fromJson(
        res['data'],
        (json) => PostModel.fromJson(json),
      );
    }

    return PageData(list: [], page: 1, pageSize: 20, total: 0);
  }

  /// 获取详情
  Future<PostModel?> getDetail(int id) async {
    final res = await _http.get(ApiConfig.postDetail, params: {'id': id});

    if (res['code'] == 0 && res['data'] != null) {
      return PostModel.fromJson(res['data']);
    }
    return null;
  }

  /// 我的发布
  Future<PageData<PostModel>> getMine({int page = 1}) async {
    final res = await _http.get(ApiConfig.postMine, params: {'page': page});

    if (res['code'] == 0 && res['data'] != null) {
      return PageData.fromJson(
        res['data'],
        (json) => PostModel.fromJson(json),
      );
    }

    return PageData(list: [], page: 1, pageSize: 20, total: 0);
  }

  /// 编辑启事（仅待审核/被驳回状态可编辑）
  Future<Map<String, dynamic>> update({
    required int id,
    String? name,
    String? appearance,
    String? description,
    String? lostAt,
    String? lostProvince,
    String? lostCity,
    String? lostDistrict,
    String? lostAddress,
    double? lostLongitude,
    double? lostLatitude,
    List<String>? images,
    int? visibility,
  }) async {
    final data = <String, dynamic>{'id': id};
    if (name != null) data['name'] = name;
    if (appearance != null) data['appearance'] = appearance;
    if (description != null) data['description'] = description;
    if (lostAt != null) data['lost_at'] = lostAt;
    if (lostProvince != null) data['lost_province'] = lostProvince;
    if (lostCity != null) data['lost_city'] = lostCity;
    if (lostDistrict != null) data['lost_district'] = lostDistrict;
    if (lostAddress != null) data['lost_address'] = lostAddress;
    if (lostLongitude != null) data['lost_longitude'] = lostLongitude;
    if (lostLatitude != null) data['lost_latitude'] = lostLatitude;
    if (images != null) data['images'] = images;
    if (visibility != null) data['visibility'] = visibility;
    return await _http.post(ApiConfig.postUpdate, data: data);
  }

  /// 更新状态
  Future<Map<String, dynamic>> updateStatus(int id, int status) async {
    return await _http.post(ApiConfig.postUpdateStatus, data: {
      'id': id,
      'status': status,
    });
  }
}
