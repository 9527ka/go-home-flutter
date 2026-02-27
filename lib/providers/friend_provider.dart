import 'package:flutter/material.dart';
import '../models/friend.dart';
import '../models/friend_request.dart';
import '../models/user.dart';
import '../providers/chat_provider.dart';
import '../services/friend_service.dart';

/// 好友状态管理
class FriendProvider extends ChangeNotifier {
  final FriendService _service = FriendService();

  List<FriendModel> _friends = [];
  List<FriendRequestModel> _requests = [];
  int _pendingRequestCount = 0;
  bool _isLoading = false;

  ChatProvider? _chatProvider;
  bool _wsRegistered = false;

  // Getters
  List<FriendModel> get friends => _friends;
  List<FriendRequestModel> get requests => _requests;
  int get pendingRequestCount => _pendingRequestCount;
  bool get isLoading => _isLoading;
  bool get hasNewRequests => _pendingRequestCount > 0;

  /// 绑定 ChatProvider 并注册 WebSocket 消息监听
  void bindChatProvider(ChatProvider chatProvider) {
    if (_wsRegistered && _chatProvider == chatProvider) return;
    _chatProvider = chatProvider;
    _wsRegistered = true;

    // 收到好友请求时，自动刷新请求计数
    chatProvider.registerHandler('friend_request', _onFriendRequest);
    // 好友请求被接受时，自动刷新好友列表
    chatProvider.registerHandler('friend_accepted', _onFriendAccepted);
  }

  void _onFriendRequest(Map<String, dynamic> data) {
    debugPrint('[Friend] WS friend_request received, refreshing count');
    fetchRequestCount();
  }

  void _onFriendAccepted(Map<String, dynamic> data) {
    debugPrint('[Friend] WS friend_accepted received, refreshing friends');
    loadFriends();
    fetchRequestCount();
  }

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
      return success ? null : 'send_failed';
    } catch (e) {
      return 'network_error';
    }
  }

  /// 接受好友请求
  /// 返回 null 表示成功，否则返回 i18n key
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
      return 'operation_failed';
    } catch (e) {
      return 'network_error';
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
      return 'operation_failed';
    } catch (e) {
      return 'network_error';
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
      return 'operation_failed';
    } catch (e) {
      return 'network_error';
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

  @override
  void dispose() {
    // 移除 WebSocket handler
    if (_chatProvider != null && _wsRegistered) {
      _chatProvider!.removeHandler('friend_request', _onFriendRequest);
      _chatProvider!.removeHandler('friend_accepted', _onFriendAccepted);
    }
    super.dispose();
  }
}
