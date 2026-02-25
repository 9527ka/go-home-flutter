import '../config/api.dart';
import '../models/group.dart';
import 'http_client.dart';

/// 群组相关 API 服务
class GroupService {
  final _http = HttpClient();

  /// 创建群组
  Future<GroupModel?> createGroup({
    required String name,
    String avatar = '',
    String description = '',
    required List<int> memberIds,
  }) async {
    final res = await _http.post(ApiConfig.groupCreate, data: {
      'name': name,
      'avatar': avatar,
      'description': description,
      'member_ids': memberIds,
    });
    if (res['code'] == 0 && res['data'] != null) {
      return GroupModel.fromJson(res['data'] as Map<String, dynamic>);
    }
    return null;
  }

  /// 获取我的群组列表
  Future<List<GroupModel>> getMyGroups() async {
    final res = await _http.get(ApiConfig.groupList);
    if (res['code'] == 0 && res['data'] != null) {
      final list = res['data']['list'] as List? ?? [];
      return list
          .map((e) => GroupModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// 获取群组详情（含成员列表）
  Future<Map<String, dynamic>?> getGroupDetail(int groupId) async {
    final res = await _http.get(
      ApiConfig.groupDetail,
      params: {'group_id': groupId},
    );
    if (res['code'] == 0 && res['data'] != null) {
      return res['data'] as Map<String, dynamic>;
    }
    return null;
  }

  /// 更新群组信息
  Future<bool> updateGroup({
    required int groupId,
    String? name,
    String? avatar,
    String? description,
  }) async {
    final data = <String, dynamic>{'group_id': groupId};
    if (name != null) data['name'] = name;
    if (avatar != null) data['avatar'] = avatar;
    if (description != null) data['description'] = description;

    final res = await _http.post(ApiConfig.groupUpdate, data: data);
    return res['code'] == 0;
  }

  /// 邀请好友入群
  Future<bool> inviteMembers(int groupId, List<int> userIds) async {
    final res = await _http.post(ApiConfig.groupInvite, data: {
      'group_id': groupId,
      'user_ids': userIds,
    });
    return res['code'] == 0;
  }

  /// 退出群组
  Future<bool> leaveGroup(int groupId) async {
    final res = await _http.post(ApiConfig.groupLeave, data: {
      'group_id': groupId,
    });
    return res['code'] == 0;
  }

  /// 踢出成员
  Future<bool> kickMember(int groupId, int userId) async {
    final res = await _http.post(ApiConfig.groupKick, data: {
      'group_id': groupId,
      'user_id': userId,
    });
    return res['code'] == 0;
  }

  /// 解散群组
  Future<bool> disbandGroup(int groupId) async {
    final res = await _http.post(ApiConfig.groupDisband, data: {
      'group_id': groupId,
    });
    return res['code'] == 0;
  }

  /// 获取群消息历史
  Future<Map<String, dynamic>> getMessages({
    required int groupId,
    int? beforeId,
    int limit = 50,
  }) async {
    final params = <String, dynamic>{
      'group_id': groupId,
      'limit': limit,
    };
    if (beforeId != null) params['before_id'] = beforeId;

    final res = await _http.get(ApiConfig.groupMessages, params: params);
    if (res['code'] == 0 && res['data'] != null) {
      return res['data'] as Map<String, dynamic>;
    }
    return {'list': [], 'has_more': false};
  }
}
