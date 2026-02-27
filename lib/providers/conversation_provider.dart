import 'package:flutter/material.dart';
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

  List<ConversationModel> get conversations => _conversations;
  int get totalUnread => _totalUnread;
  bool get hasUnread => _totalUnread > 0;
  bool get isLoading => _isLoading;

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
    // 对方发给我的用 from_id，我发给对方的用 to_id
    final friendId = fromId as int;

    final content = data['content'] as String? ?? '';
    final msgType = data['msg_type'] as String? ?? 'text';
    final time = data['created_at'] as String? ?? DateTime.now().toIso8601String();

    // 发送者昵称和头像（用于新建会话时显示）
    final nickname = data['from_nickname'] as String? ??
        data['nickname'] as String? ??
        data['user']?['nickname'] as String? ??
        '';
    final avatar = data['from_avatar'] as String? ??
        data['avatar'] as String? ??
        data['user']?['avatar'] as String? ??
        '';

    _updateConversation(
      targetId: friendId,
      targetType: 'private',
      name: nickname,
      avatar: avatar,
      lastMessage: content,
      lastMsgType: msgType,
      lastMsgTime: time,
      incrementUnread: true,
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

    _updateConversation(
      targetId: groupId,
      targetType: 'group',
      name: groupName,
      avatar: groupAvatar,
      lastMessage: content,
      lastMsgType: msgType,
      lastMsgTime: time,
      incrementUnread: true,
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
  }

  /// 加载会话列表（全量刷新）
  Future<void> loadConversations() async {
    _isLoading = true;
    notifyListeners();

    try {
      _conversations = await _pmService.getConversations();
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

  @override
  void dispose() {
    _unbindChatProvider();
    super.dispose();
  }
}
