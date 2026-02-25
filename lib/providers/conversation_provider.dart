import 'package:flutter/material.dart';
import '../models/conversation.dart';
import '../services/pm_service.dart';

/// 会话列表状态管理（私聊 + 群聊）
class ConversationProvider extends ChangeNotifier {
  final PmService _pmService = PmService();

  List<ConversationModel> _conversations = [];
  int _totalUnread = 0;
  bool _isLoading = false;

  List<ConversationModel> get conversations => _conversations;
  int get totalUnread => _totalUnread;
  bool get hasUnread => _totalUnread > 0;
  bool get isLoading => _isLoading;

  /// 加载会话列表
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
}
