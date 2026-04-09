import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/conversation.dart';
import '../providers/chat_provider.dart';
import '../services/pm_service.dart';

/// 会话列表状态管理（私聊 + 群聊）
///
/// 支持两种刷新方式：
/// 1. 全量刷新 [loadConversations] — 从服务端拉取完整列表
/// 2. 实时更新 — 通过 WebSocket 收到新消息时，本地更新最后一条消息预览并置顶
class ConversationProvider extends ChangeNotifier {
  final PmService _pmService = PmService();

  List<ConversationModel> _conversations = [];
  int _totalUnread = 0;
  bool _isLoading = false;

  /// 关联的 ChatProvider，用于注册 WebSocket handler
  ChatProvider? _chatProvider;

  /// 当前用户 ID（用于区分消息方向）
  int? _currentUserId;

  /// 当前正在查看的会话（targetId + targetType），用于判断是否增加未读数
  int? _activeTargetId;
  String? _activeTargetType;

  List<ConversationModel> get conversations => _conversations;
  int get totalUnread => _totalUnread;
  bool get hasUnread => _totalUnread > 0;
  bool get isLoading => _isLoading;

  /// 设置当前用户 ID
  void setCurrentUserId(int? userId) {
    _currentUserId = userId;
  }

  /// 进入某个会话页面时调用，标记为活跃会话（不增加未读数）
  void setActiveConversation(int targetId, String targetType) {
    _activeTargetId = targetId;
    _activeTargetType = targetType;
  }

  /// 离开会话页面时调用，清除活跃会话
  void clearActiveConversation() {
    _activeTargetId = null;
    _activeTargetType = null;
  }

  /// 绑定 ChatProvider，注册 WebSocket 监听
  void bindChatProvider(ChatProvider chatProvider) {
    if (_chatProvider == chatProvider) return;
    // 移除旧的
    _unbindChatProvider();
    _chatProvider = chatProvider;
    _chatProvider!.registerHandler('private_message', _onPrivateMessage);
    _chatProvider!.registerHandler('group_message', _onGroupMessage);
  }

  void _unbindChatProvider() {
    if (_chatProvider != null) {
      _chatProvider!.removeHandler('private_message', _onPrivateMessage);
      _chatProvider!.removeHandler('group_message', _onGroupMessage);
      _chatProvider = null;
    }
  }

  /// 收到私聊消息时，更新对应会话的最后消息预览
  void _onPrivateMessage(Map<String, dynamic> data) {
    final fromId = data['from_id'] ?? data['user_id'] ?? 0;
    final toId = data['to_id'] ?? 0;

    // 判断消息方向：自己发的用 to_id 作为会话对象，对方发的用 from_id
    final bool isSentByMe = _currentUserId != null && fromId == _currentUserId;
    final int friendId = isSentByMe ? (toId as int) : (fromId as int);
    if (friendId <= 0) return;

    final content = data['content'] as String? ?? '';
    final msgType = data['msg_type'] as String? ?? 'text';
    final time = data['created_at'] as String? ?? DateTime.now().toIso8601String();

    // 对方的昵称和头像（用于新建会话时显示）
    String nickname;
    String avatar;
    if (isSentByMe) {
      // 自己发的消息，取接收方信息
      nickname = data['to_nickname'] as String? ?? '';
      avatar = data['to_avatar'] as String? ?? '';
    } else {
      nickname = data['from_nickname'] as String? ??
          data['nickname'] as String? ??
          data['user']?['nickname'] as String? ??
          '';
      avatar = data['from_avatar'] as String? ??
          data['avatar'] as String? ??
          data['user']?['avatar'] as String? ??
          '';
    }

    // 自己发的消息不增加未读；正在查看该会话时也不增加未读
    final bool isActive = _activeTargetId == friendId && _activeTargetType == 'private';
    final bool shouldIncrementUnread = !isSentByMe && !isActive;

    _updateConversation(
      targetId: friendId,
      targetType: 'private',
      name: nickname,
      avatar: avatar,
      lastMessage: content,
      lastMsgType: msgType,
      lastMsgTime: time,
      incrementUnread: shouldIncrementUnread,
    );
  }

  /// 收到群聊消息时，更新对应群会话的最后消息预览
  void _onGroupMessage(Map<String, dynamic> data) {
    final groupId = data['group_id'] as int? ?? 0;
    if (groupId <= 0) return;

    final content = data['content'] as String? ?? '';
    final msgType = data['msg_type'] as String? ?? 'text';
    final time = data['created_at'] as String? ?? DateTime.now().toIso8601String();

    // 群组名（如果服务端推送中包含的话）
    final groupName = data['group_name'] as String? ?? '';
    final groupAvatar = data['group_avatar'] as String? ?? '';

    // 自己发的消息或正在查看该群时不增加未读
    final fromId = data['from_id'] ?? data['user_id'] ?? 0;
    final bool isSentByMe = _currentUserId != null && fromId == _currentUserId;
    final bool isActive = _activeTargetId == groupId && _activeTargetType == 'group';
    final bool shouldIncrementUnread = !isSentByMe && !isActive;

    _updateConversation(
      targetId: groupId,
      targetType: 'group',
      name: groupName,
      avatar: groupAvatar,
      lastMessage: content,
      lastMsgType: msgType,
      lastMsgTime: time,
      incrementUnread: shouldIncrementUnread,
    );
  }

  /// 更新或创建会话，并置顶到列表最前面
  void _updateConversation({
    required int targetId,
    required String targetType,
    required String lastMessage,
    required String lastMsgType,
    required String lastMsgTime,
    String name = '',
    String avatar = '',
    bool incrementUnread = false,
  }) {
    final idx = _conversations.indexWhere(
      (c) => c.targetId == targetId && c.targetType == targetType,
    );

    if (idx >= 0) {
      // 已有会话 — 更新最后消息，保留原有 name / avatar
      final old = _conversations[idx];
      final updated = ConversationModel(
        targetId: old.targetId,
        targetType: old.targetType,
        name: name.isNotEmpty ? name : old.name,
        avatar: avatar.isNotEmpty ? avatar : old.avatar,
        lastMessage: lastMessage,
        lastMsgType: lastMsgType,
        lastMsgTime: lastMsgTime,
        unreadCount: incrementUnread ? old.unreadCount + 1 : old.unreadCount,
      );
      _conversations.removeAt(idx);
      _conversations.insert(0, updated); // 置顶
    } else {
      // 新会话 — 插入到列表最前面
      _conversations.insert(
        0,
        ConversationModel(
          targetId: targetId,
          targetType: targetType,
          name: name,
          avatar: avatar,
          lastMessage: lastMessage,
          lastMsgType: lastMsgType,
          lastMsgTime: lastMsgTime,
          unreadCount: incrementUnread ? 1 : 0,
        ),
      );
    }

    _totalUnread = _conversations.fold(0, (sum, c) => sum + c.unreadCount);
    notifyListeners();

    // 播放消息提示音（非免打扰 + 有新未读消息时）
    if (incrementUnread) {
      _playNotificationSound(targetId, targetType);
    }
  }

  /// 播放消息提示音（检查免打扰状态）
  void _playNotificationSound(int targetId, String targetType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final muted = prefs.getBool('conv_mute_${targetType}_$targetId') ?? false;
      if (!muted) {
        const channel = MethodChannel('com.gohome/sound');
        await channel.invokeMethod('playMessageSound');
      }
    } catch (e) {
      debugPrint('[Conversation] playNotificationSound error: $e');
    }
  }

  /// 发送消息后更新会话（由发送方主动调用）
  void onMessageSent({
    required int targetId,
    required String targetType,
    required String content,
    String msgType = 'text',
    String name = '',
    String avatar = '',
  }) {
    _updateConversation(
      targetId: targetId,
      targetType: targetType,
      lastMessage: content,
      lastMsgType: msgType,
      lastMsgTime: DateTime.now().toIso8601String(),
      name: name,
      avatar: avatar,
      incrementUnread: false,
    );
  }

  /// 加载会话列表（全量刷新，保留本地新增的会话及本地更高的未读数）
  Future<void> loadConversations() async {
    _isLoading = true;
    notifyListeners();

    try {
      // 快照当前本地未读数（WebSocket 实时递增的可能比服务端更新）
      final localUnreadMap = <String, int>{};
      for (final c in _conversations) {
        localUnreadMap['${c.targetType}_${c.targetId}'] = c.unreadCount;
      }

      final serverList = await _pmService.getConversations();

      // 合并：取 max(服务端, 本地) 的未读数，避免 WebSocket 递增被覆盖
      final merged = serverList.map((c) {
        final key = '${c.targetType}_${c.targetId}';
        final localUnread = localUnreadMap[key] ?? 0;
        if (localUnread > c.unreadCount) {
          return ConversationModel(
            targetId: c.targetId,
            targetType: c.targetType,
            name: c.name,
            avatar: c.avatar,
            lastMessage: c.lastMessage,
            lastMsgType: c.lastMsgType,
            lastMsgTime: c.lastMsgTime,
            unreadCount: localUnread,
          );
        }
        return c;
      }).toList();

      // 找出本地存在但服务端尚未返回的会话（刚发送消息，服务端还没记录）
      final serverKeys = <String>{};
      for (final c in merged) {
        serverKeys.add('${c.targetType}_${c.targetId}');
      }

      final localOnly = _conversations.where((c) {
        return !serverKeys.contains('${c.targetType}_${c.targetId}');
      }).toList();

      // 服务端列表优先，再补上本地独有的会话
      _conversations = [...merged, ...localOnly];
      _totalUnread = _conversations.fold(0, (sum, c) => sum + c.unreadCount);
    } catch (e) {
      debugPrint('[Conversation] loadConversations error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 标记会话已读
  Future<void> markRead(int targetId, String targetType) async {
    try {
      if (targetType == 'private') {
        await _pmService.markRead(targetId);
      }
      // 本地更新未读数
      final idx = _conversations.indexWhere(
        (c) => c.targetId == targetId && c.targetType == targetType,
      );
      if (idx >= 0) {
        final old = _conversations[idx];
        _conversations[idx] = ConversationModel(
          targetId: old.targetId,
          targetType: old.targetType,
          name: old.name,
          avatar: old.avatar,
          lastMessage: old.lastMessage,
          lastMsgType: old.lastMsgType,
          lastMsgTime: old.lastMsgTime,
          unreadCount: 0,
        );
        _totalUnread = _conversations.fold(0, (sum, c) => sum + c.unreadCount);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[Conversation] markRead error: $e');
    }
  }

  /// 移除会话（本地删除，不影响聊天记录）
  void removeConversation(int targetId, String targetType) {
    _conversations.removeWhere(
      (c) => c.targetId == targetId && c.targetType == targetType,
    );
    _totalUnread = _conversations.fold(0, (sum, c) => sum + c.unreadCount);
    notifyListeners();
  }

  // ===== 免打扰（本地偏好） =====

  /// 检查会话是否已开启免打扰
  Future<bool> isConversationMuted(int targetId, String targetType) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('conv_mute_${targetType}_$targetId') ?? false;
  }

  /// 切换会话免打扰
  Future<void> setConversationMuted(int targetId, String targetType, bool muted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('conv_mute_${targetType}_$targetId', muted);
    notifyListeners();
  }

  @override
  void dispose() {
    _unbindChatProvider();
    super.dispose();
  }
}
