import '../config/api.dart';
import '../models/api_response.dart';
import '../models/post.dart';
import 'http_client.dart';

class FavoriteService {
  final _http = HttpClient();

  /// 获取收藏列表
  Future<PageData<PostModel>> getList({int page = 1, int pageSize = 20}) async {
    final res = await _http.get(ApiConfig.favoriteList, params: {
      'page': page,
      'page_size': pageSize,
    });

    if (res['code'] == 0 && res['data'] != null) {
      return PageData.fromJson(
        res['data'],
        (json) => PostModel.fromJson(json),
      );
    }

    return PageData(list: [], page: 1, pageSize: 20, total: 0);
  }

  /// 切换收藏状态
  Future<Map<String, dynamic>> toggle(int postId) async {
    return await _http.post(ApiConfig.favoriteToggle, data: {
      'post_id': postId,
    });
  }
}
