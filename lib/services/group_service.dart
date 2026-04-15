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
    String? announcement,
  }) async {
    final data = <String, dynamic>{'group_id': groupId};
    if (name != null) data['name'] = name;
    if (avatar != null) data['avatar'] = avatar;
    if (description != null) data['description'] = description;
    if (announcement != null) data['announcement'] = announcement;

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

  /// 设置群成员角色 (role: 0=普通成员, 1=管理员)
  Future<bool> setMemberRole(int groupId, int userId, int role) async {
    final res = await _http.post(ApiConfig.groupSetRole, data: {
      'group_id': groupId,
      'user_id': userId,
      'role': role,
    });
    return res['code'] == 0;
  }

  /// 群主/管理员禁言群内某成员
  /// minutes: 0=解除；-1=永久；>0=指定分钟数
  Future<bool> muteMember({
    required int groupId,
    required int userId,
    required int minutes,
  }) async {
    final res = await _http.post(ApiConfig.groupMuteMember, data: {
      'group_id': groupId,
      'user_id': userId,
      'minutes': minutes,
    });
    return res['code'] == 0;
  }

  /// 群主/管理员开关"全员禁言"
  Future<bool> setAllMuted(int groupId, bool allMuted) async {
    final res = await _http.post(ApiConfig.groupSetAllMuted, data: {
      'group_id': groupId,
      'all_muted': allMuted ? 1 : 0,
    });
    return res['code'] == 0;
  }

  /// 设置我在本群的昵称（别名）；传空串表示清除
  Future<bool> setMyAlias(int groupId, String alias) async {
    final res = await _http.post(ApiConfig.groupSetAlias, data: {
      'group_id': groupId,
      'alias': alias,
    });
    return res['code'] == 0;
  }

  /// 生成群邀请 token（默认 7 天有效）
  ///
  /// 返回 `{data: {...}}` 或 `{error: 'msg'}`（便于调用方显示真实错误原因，而非统一 "网络异常"）
  Future<Map<String, dynamic>> createInviteToken(int groupId, {int ttl = 7 * 86400}) async {
    final res = await _http.post(ApiConfig.groupInviteToken, data: {
      'group_id': groupId,
      'ttl': ttl,
    });
    if (res['code'] == 0 && res['data'] != null) {
      return {'data': res['data'] as Map<String, dynamic>};
    }
    return {'error': (res['msg'] ?? '').toString()};
  }

  /// 通过 token 加入群（扫码 / 邀请链接）
  Future<Map<String, dynamic>?> joinByToken(String token) async {
    final res = await _http.post(ApiConfig.groupJoinByToken, data: {'token': token});
    if (res['code'] == 0 && res['data'] != null) {
      return res['data'] as Map<String, dynamic>;
    }
    return null;
  }

  /// 解散群组
  Future<bool> disbandGroup(int groupId) async {
    final res = await _http.post(ApiConfig.groupDisband, data: {
      'group_id': groupId,
    });
    return res['code'] == 0;
  }

  /// 获取群消息历史 / 搜索
  /// keyword 非空时进行后端关键词搜索（仅匹配 text 类型消息）
  Future<Map<String, dynamic>> getMessages({
    required int groupId,
    int? beforeId,
    int limit = 50,
    String keyword = '',
  }) async {
    final params = <String, dynamic>{
      'group_id': groupId,
      'limit': limit,
    };
    if (beforeId != null) params['before_id'] = beforeId;
    if (keyword.isNotEmpty) params['keyword'] = keyword;

    final res = await _http.get(ApiConfig.groupMessages, params: params);
    if (res['code'] == 0 && res['data'] != null) {
      return res['data'] as Map<String, dynamic>;
    }
    return {'list': [], 'has_more': false};
  }
}
