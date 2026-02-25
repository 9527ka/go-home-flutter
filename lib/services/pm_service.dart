import '../config/api.dart';
import '../models/conversation.dart';
import 'http_client.dart';

/// 私聊相关 API 服务
class PmService {
  final _http = HttpClient();

  /// 获取与某好友的私聊历史
  Future<Map<String, dynamic>> getHistory({
    required int friendId,
    int? beforeId,
    int limit = 50,
  }) async {
    final params = <String, dynamic>{
      'friend_id': friendId,
      'limit': limit,
    };
    if (beforeId != null) params['before_id'] = beforeId;

    final res = await _http.get(ApiConfig.pmHistory, params: params);
    if (res['code'] == 0 && res['data'] != null) {
      return res['data'] as Map<String, dynamic>;
    }
    return {'list': [], 'has_more': false};
  }

  /// 获取会话列表（私聊 + 群聊）
  Future<List<ConversationModel>> getConversations() async {
    final res = await _http.get(ApiConfig.pmConversations);
    if (res['code'] == 0 && res['data'] != null) {
      final list = res['data']['list'] as List? ?? [];
      return list
          .map((e) => ConversationModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// 标记会话已读
  Future<bool> markRead(int friendId) async {
    final res = await _http.post(ApiConfig.pmRead, data: {
      'friend_id': friendId,
    });
    return res['code'] == 0;
  }
}
