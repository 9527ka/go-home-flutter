import '../config/api.dart';
import '../models/friend.dart';
import '../models/friend_request.dart';
import '../models/user.dart';
import 'http_client.dart';

/// 好友相关 API 服务
class FriendService {
  final _http = HttpClient();

  /// 发送好友请求，返回完整响应以便上层区分具体错误
  Future<Map<String, dynamic>> sendRequest({required int toId, String message = ''}) async {
    return await _http.post(ApiConfig.friendRequest, data: {
      'to_id': toId,
      'message': message,
    });
  }

  /// 获取收到的待处理好友请求
  Future<List<FriendRequestModel>> getRequests() async {
    final res = await _http.get(ApiConfig.friendRequests);
    if (res['code'] == 0 && res['data'] != null) {
      final list = res['data']['list'] as List? ?? [];
      return list
          .map((e) => FriendRequestModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// 接受好友请求
  Future<bool> acceptRequest(int requestId) async {
    final res = await _http.post(ApiConfig.friendAccept, data: {
      'request_id': requestId,
    });
    return res['code'] == 0;
  }

  /// 拒绝好友请求
  Future<bool> rejectRequest(int requestId) async {
    final res = await _http.post(ApiConfig.friendReject, data: {
      'request_id': requestId,
    });
    return res['code'] == 0;
  }

  /// 获取好友列表
  Future<List<FriendModel>> getFriendList() async {
    final res = await _http.get(ApiConfig.friendList);
    if (res['code'] == 0 && res['data'] != null) {
      final list = res['data']['list'] as List? ?? [];
      return list
          .map((e) => FriendModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// 删除好友
  Future<bool> removeFriend(int friendId) async {
    final res = await _http.post(ApiConfig.friendRemove, data: {
      'friend_id': friendId,
    });
    return res['code'] == 0;
  }

  /// 搜索用户（手机号或用户 ID）
  Future<List<UserModel>> searchUsers(String keyword) async {
    final res = await _http.get(
      ApiConfig.friendSearch,
      params: {'keyword': keyword},
    );
    if (res['code'] == 0 && res['data'] != null) {
      final list = res['data']['list'] as List? ?? [];
      return list
          .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// 修改好友备注
  Future<bool> updateRemark(int friendId, String remark) async {
    final res = await _http.post(ApiConfig.friendRemark, data: {
      'friend_id': friendId,
      'remark': remark,
    });
    return res['code'] == 0;
  }

  /// 获取待处理请求数量
  Future<int> getRequestCount() async {
    final res = await _http.get(ApiConfig.friendRequestCount);
    if (res['code'] == 0 && res['data'] != null) {
      return res['data']['count'] ?? 0;
    }
    return 0;
  }
}
