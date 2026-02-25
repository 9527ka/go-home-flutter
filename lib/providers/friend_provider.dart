import 'package:flutter/material.dart';
import '../models/friend.dart';
import '../models/friend_request.dart';
import '../models/user.dart';
import '../services/friend_service.dart';

/// 好友状态管理
class FriendProvider extends ChangeNotifier {
  final FriendService _service = FriendService();

  List<FriendModel> _friends = [];
  List<FriendRequestModel> _requests = [];
  int _pendingRequestCount = 0;
  bool _isLoading = false;

  // Getters
  List<FriendModel> get friends => _friends;
  List<FriendRequestModel> get requests => _requests;
  int get pendingRequestCount => _pendingRequestCount;
  bool get isLoading => _isLoading;
  bool get hasNewRequests => _pendingRequestCount > 0;

  /// 加载好友列表
  Future<void> loadFriends() async {
    _isLoading = true;
    notifyListeners();

    try {
      _friends = await _service.getFriendList();
    } catch (e) {
      debugPrint('[Friend] loadFriends error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 加载好友请求列表
  Future<void> loadRequests() async {
    try {
      _requests = await _service.getRequests();
      _pendingRequestCount = _requests.length;
      notifyListeners();
    } catch (e) {
      debugPrint('[Friend] loadRequests error: $e');
    }
  }

  /// 获取待处理请求数量（轻量 API）
  Future<void> fetchRequestCount() async {
    try {
      _pendingRequestCount = await _service.getRequestCount();
      notifyListeners();
    } catch (e) {
      debugPrint('[Friend] fetchRequestCount error: $e');
    }
  }

  /// 发送好友请求
  Future<String?> sendRequest({required int toId, String message = ''}) async {
    try {
      final success = await _service.sendRequest(toId: toId, message: message);
      return success ? null : '发送失败';
    } catch (e) {
      return '网络异常，请重试';
    }
  }

  /// 接受好友请求
  Future<String?> acceptRequest(int requestId) async {
    try {
      final success = await _service.acceptRequest(requestId);
      if (success) {
        _requests.removeWhere((r) => r.id == requestId);
        _pendingRequestCount = _requests.length;
        // 刷新好友列表
        loadFriends();
        notifyListeners();
        return null;
      }
      return '操作失败';
    } catch (e) {
      return '网络异常，请重试';
    }
  }

  /// 拒绝好友请求
  Future<String?> rejectRequest(int requestId) async {
    try {
      final success = await _service.rejectRequest(requestId);
      if (success) {
        _requests.removeWhere((r) => r.id == requestId);
        _pendingRequestCount = _requests.length;
        notifyListeners();
        return null;
      }
      return '操作失败';
    } catch (e) {
      return '网络异常，请重试';
    }
  }

  /// 删除好友
  Future<String?> removeFriend(int friendId) async {
    try {
      final success = await _service.removeFriend(friendId);
      if (success) {
        _friends.removeWhere((f) => f.userId == friendId);
        notifyListeners();
        return null;
      }
      return '操作失败';
    } catch (e) {
      return '网络异常，请重试';
    }
  }

  /// 搜索用户
  Future<List<UserModel>> searchUsers(String keyword) async {
    try {
      return await _service.searchUsers(keyword);
    } catch (e) {
      debugPrint('[Friend] searchUsers error: $e');
      return [];
    }
  }

  /// 判断某用户是否是好友
  bool isFriend(int userId) => _friends.any((f) => f.userId == userId);
}
