import '../config/api.dart';
import 'http_client.dart';

class LikeService {
  final _http = HttpClient();

  /// 点赞/取消点赞
  Future<Map<String, dynamic>> toggle({
    required int targetType,
    required int targetId,
  }) async {
    return await _http.post(ApiConfig.likeToggle, data: {
      'target_type': targetType,
      'target_id': targetId,
    });
  }

  /// 批量查询点赞状态
  Future<List<int>> getStatus({
    required int targetType,
    required List<int> targetIds,
  }) async {
    if (targetIds.isEmpty) return [];
    final res = await _http.get(ApiConfig.likeStatus, params: {
      'target_type': targetType,
      'target_ids': targetIds.join(','),
    });
    if (res['code'] == 0 && res['data'] != null) {
      return (res['data']['liked_ids'] as List).map((e) => e as int).toList();
    }
    return [];
  }
}
