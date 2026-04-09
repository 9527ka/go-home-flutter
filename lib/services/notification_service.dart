import '../config/api.dart';
import '../models/api_response.dart';
import '../models/notification.dart';
import 'http_client.dart';

class NotificationService {
  final _http = HttpClient();

  /// 获取通知列表
  Future<PageData<NotificationModel>> getList({int page = 1, int pageSize = 20}) async {
    final res = await _http.get(ApiConfig.notificationList, params: {
      'page': page,
      'page_size': pageSize,
    });

    if (res['code'] == 0 && res['data'] != null) {
      return PageData.fromJson(
        res['data'],
        (json) => NotificationModel.fromJson(json),
      );
    }

    return PageData(list: [], page: 1, pageSize: 20, total: 0);
  }

  /// 获取未读数量
  Future<int> getUnreadCount() async {
    final res = await _http.get(ApiConfig.notificationUnread);
    if (res['code'] == 0 && res['data'] != null) {
      return res['data']['count'] ?? 0;
    }
    return 0;
  }

  /// 标记为已读（传 id 标记单条，不传标记全部）
  Future<Map<String, dynamic>> markRead({int? id}) async {
    final data = <String, dynamic>{};
    if (id != null) data['id'] = id;
    return await _http.post(ApiConfig.notificationRead, data: data);
  }

  /// 删除全部已读通知
  Future<Map<String, dynamic>> deleteAll() async {
    return await _http.post(ApiConfig.notificationDeleteAll);
  }
}
