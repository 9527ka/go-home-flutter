import 'package:flutter/material.dart';
import '../models/group.dart';
import '../services/group_service.dart';

/// 群组状态管理
class GroupProvider extends ChangeNotifier {
  final GroupService _service = GroupService();

  List<GroupModel> _groups = [];
  bool _isLoading = false;

  List<GroupModel> get groups => _groups;
  bool get isLoading => _isLoading;

  /// 加载我的群组列表
  Future<void> loadGroups() async {
    _isLoading = true;
    notifyListeners();

    try {
      _groups = await _service.getMyGroups();
    } catch (e) {
      debugPrint('[Group] loadGroups error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 创建群组
  Future<GroupModel?> createGroup({
    required String name,
    String avatar = '',
    String description = '',
    required List<int> memberIds,
  }) async {
    try {
      final group = await _service.createGroup(
        name: name,
        avatar: avatar,
        description: description,
        memberIds: memberIds,
      );
      if (group != null) {
        _groups.insert(0, group);
        notifyListeners();
      }
      return group;
    } catch (e) {
      debugPrint('[Group] createGroup error: $e');
      return null;
    }
  }

  /// 退出群组
  Future<bool> leaveGroup(int groupId) async {
    try {
      final success = await _service.leaveGroup(groupId);
      if (success) {
        _groups.removeWhere((g) => g.id == groupId);
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('[Group] leaveGroup error: $e');
      return false;
    }
  }

  /// 解散群组
  Future<bool> disbandGroup(int groupId) async {
    try {
      final success = await _service.disbandGroup(groupId);
      if (success) {
        _groups.removeWhere((g) => g.id == groupId);
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('[Group] disbandGroup error: $e');
      return false;
    }
  }
}
