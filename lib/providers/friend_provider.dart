import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/in_app_notifier.dart';
import '../models/friend.dart';
import '../models/friend_request.dart';
import '../models/user.dart';
import '../providers/chat_provider.dart';
import '../providers/conversation_provider.dart';
import '../services/friend_service.dart';

/// 好友状态管理
class FriendProvider extends ChangeNotifier {
  final FriendService _service = FriendService();

  List<FriendModel> _friends = [];
  List<FriendRequestModel> _requests = [];
  int _pendingRequestCount = 0;
  bool _isLoading = false;

  ChatProvider? _chatProvider;
  ConversationProvider? _conversationProvider;
  bool _wsRegistered = false;

  bool _loaded = false;

  /// 最近一次收到的好友申请者昵称/头像（用于会话列表"新的朋友"入口副标题）
  String _latestRequesterNickname = '';
  String _latestRequesterAvatar = '';
  String _latestRequestTime = '';

  /// 翻译函数（由外部注入，用于 WebSocket 通知横幅本地化）
  String Function(String key)? _tr;

  // Getters
  List<FriendModel> get friends => _friends;
  List<FriendRequestModel> get requests => _requests;
  int get pendingRequestCount => _pendingRequestCount;
  bool get isLoading => _isLoading;
  bool get isLoaded => _loaded;
  bool get hasNewRequests => _pendingRequestCount > 0;
  String get latestRequesterNickname => _latestRequesterNickname;
  String get latestRequesterAvatar => _latestRequesterAvatar;
  String get latestRequestTime => _latestRequestTime;

  /// 设置翻译函数（Provider 内无 BuildContext，需外部注入）
  void setTranslator(String Function(String key) tr) {
    _tr = tr;
  }

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

  /// 绑定 ConversationProvider（用于新好友时同步会话列表）
  void bindConversationProvider(ConversationProvider conversationProvider) {
    _conversationProvider = conversationProvider;
  }

  void _onFriendRequest(Map<String, dynamic> data) {
    debugPrint('[Friend] WS friend_request received: $data');
    // 记录最近一次申请者信息（会话列表入口用）
    final nickname = (data['from_nickname'] as String?) ?? '';
    final avatar = (data['from_avatar'] as String?) ?? '';
    _latestRequesterNickname = nickname;
    _latestRequesterAvatar = avatar;
    _latestRequestTime = DateTime.now().toIso8601String();

    // 本地乐观递增计数，立即触发红点/横幅显示
    _pendingRequestCount += 1;
    notifyListeners();

    // 播放提示音 + 本地通知横幅（与新消息通知保持一致）
    _notifyNewFriendRequest(nickname);

    // 再从服务端拉取权威数量
    fetchRequestCount();
  }

  /// 播放提示音并显示通知横幅（应用内 + 系统双通道）
  Future<void> _notifyNewFriendRequest(String nickname) async {
    final title = nickname.isNotEmpty
        ? nickname
        : (_tr?.call('new_friends_entry') ?? 'New Friends');
    final body = _tr?.call('friend_request_wants_to_add') ??
        'wants to add you as a friend';

    // 应用内横幅（前台兜底）
    InAppNotifier.show(title: title, body: body);

    try {
      // 好友申请通知不走单聊免打扰开关，这是独立事件
      const channel = MethodChannel('com.gohome/sound');
      await channel.invokeMethod('playMessageSound');
      await channel.invokeMethod('showLocalNotification', {
        'title': title,
        'body': body,
      });
    } catch (e) {
      debugPrint('[Friend] _notifyNewFriendRequest error: $e');
    }
  }

  void _onFriendAccepted(Map<String, dynamic> data) {
    debugPrint('[Friend] WS friend_accepted received: $data');
    final acceptedUserId = data['accepted_user_id'] as int? ?? 0;
    final nickname = data['nickname'] as String? ?? '';
    final avatar = data['avatar'] as String? ?? '';
    final userCode = data['user_code'] as String? ?? '';

    // 立即本地插入好友（避免等待服务端响应造成的延迟）
    if (acceptedUserId > 0 && !isFriend(acceptedUserId)) {
      _friends.insert(0, FriendModel(
        id: 0,
        userId: acceptedUserId,
        nickname: nickname,
        avatar: avatar,
        userCode: userCode,
        createdAt: DateTime.now().toIso8601String(),
      ));
      notifyListeners();

      // 同步到会话列表（显示新好友的会话项）
      if (_conversationProvider != null) {
        _conversationProvider!.onMessageSent(
          targetId: acceptedUserId,
          targetType: 'private',
          content: '',
          name: nickname,
          avatar: avatar,
        );
      }
    }

    // 再从服务端拉取权威数据
    loadFriends();
    fetchRequestCount();
  }

  /// 仅在尚未加载过时从服务端拉取，已有数据则跳过
  Future<void> loadFriendsIfEmpty() async {
    if (_loaded && _friends.isNotEmpty) return;
    await loadFriends();
  }

  /// 加载好友列表
  Future<void> loadFriends() async {
    _isLoading = true;
    notifyListeners();

    try {
      _friends = await _service.getFriendList();
      _loaded = true;
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
      // 同步最新申请者信息（列表已按 created_at desc 排序）
      if (_requests.isNotEmpty) {
        final latest = _requests.first;
        _latestRequesterNickname = latest.fromNickname;
        _latestRequesterAvatar = latest.fromAvatar;
        _latestRequestTime = latest.createdAt;
      } else {
        _latestRequesterNickname = '';
        _latestRequesterAvatar = '';
        _latestRequestTime = '';
      }
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
  /// 返回 null 表示成功，否则返回服务端提示信息
  Future<String?> sendRequest({required int toId, String message = ''}) async {
    try {
      final res = await _service.sendRequest(toId: toId, message: message);
      if (res['code'] == 0) return null;
      // 返回服务端的具体提示（如"已发送过请求，请等待对方处理"）
      final msg = res['msg'] as String?;
      return (msg != null && msg.isNotEmpty) ? msg : '发送失败';
    } catch (e) {
      return '网络异常，请稍后再试';
    }
  }

  /// 接受好友请求
  /// [greetingPreview] 用于在本地会话列表显示的问候消息预览（已本地化）
  /// 返回 null 表示成功，否则返回 i18n key
  Future<String?> acceptRequest(int requestId, {String greetingPreview = ''}) async {
    try {
      // 先取出该请求的发起方信息（用于立即添加好友和会话）
      final req = _requests.firstWhere(
        (r) => r.id == requestId,
        orElse: () => FriendRequestModel(id: 0, fromId: 0, toId: 0),
      );
      final success = await _service.acceptRequest(requestId);
      if (success) {
        _requests.removeWhere((r) => r.id == requestId);
        _pendingRequestCount = _requests.length;

        // 立即本地插入新好友
        if (req.fromId > 0 && !isFriend(req.fromId)) {
          _friends.insert(0, FriendModel(
            id: 0,
            userId: req.fromId,
            nickname: req.fromNickname,
            avatar: req.fromAvatar,
            createdAt: DateTime.now().toIso8601String(),
          ));
        }
        notifyListeners();

        // 同步到会话列表（新好友显示在会话列表中）
        if (req.fromId > 0 && _conversationProvider != null) {
          _conversationProvider!.onMessageSent(
            targetId: req.fromId,
            targetType: 'private',
            content: greetingPreview,
            name: req.fromNickname,
            avatar: req.fromAvatar,
          );
        }

        // 再从服务端拉取权威数据
        loadFriends();
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

  /// 清空所有本地状态（切换账号/登出时调用）
  /// 不解绑 ChatProvider，因为 ChatProvider 自己也会 reset
  void resetSession() {
    _friends = [];
    _requests = [];
    _pendingRequestCount = 0;
    _latestRequesterNickname = '';
    _latestRequesterAvatar = '';
    _latestRequestTime = '';
    _loaded = false;
    _isLoading = false;
    notifyListeners();
  }

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
