import '../config/api.dart';
import '../models/api_response.dart';
import '../models/found_story.dart';
import 'http_client.dart';

class FoundStoryService {
  final _http = HttpClient();

  /// 仅标记已找到
  Future<Map<String, dynamic>> markFound(int postId) async {
    return await _http.post(ApiConfig.postMarkFound, data: {'id': postId});
  }

  /// 提交找回故事
  Future<Map<String, dynamic>> submit({
    required int postId,
    required String content,
    List<String> images = const [],
    String? foundAt,
  }) async {
    return await _http.post(ApiConfig.postFoundStorySubmit, data: {
      'post_id': postId,
      'content': content,
      'images': images,
      if (foundAt != null) 'found_at': foundAt,
    });
  }

  /// 公开列表
  Future<PageData<FoundStoryModel>> publicList({int page = 1}) async {
    final res = await _http.get(ApiConfig.postFoundStoryList, params: {'page': page});
    if (res['code'] == 0 && res['data'] != null) {
      return PageData.fromJson(
        res['data'],
        (json) => FoundStoryModel.fromJson(json),
      );
    }
    return PageData(list: [], page: 1, pageSize: 20, total: 0);
  }

  /// 详情
  Future<FoundStoryModel?> detail(int postId) async {
    final res = await _http.get(ApiConfig.postFoundStoryDetail, params: {'post_id': postId});
    if (res['code'] == 0 && res['data'] != null) {
      return FoundStoryModel.fromJson(res['data'] as Map<String, dynamic>);
    }
    return null;
  }
}
