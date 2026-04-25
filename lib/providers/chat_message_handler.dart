import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/chat_message.dart';

/// 处理 WebSocket 收到的消息：解析、去重、路由到内部回调或外部 handler。
class ChatMessageHandler {
  // ===== 配置常量 =====
  static const int maxMessageCacheSize = 500;

  // ===== 消息状态 =====
  final List<ChatMessageModel> _messages = [];
  final Set<int> _messageIds = {};
  bool hasMore = true;

  List<ChatMessageModel> get messages => _messages;
  Set<int> get messageIds => _messageIds;

  // ===== 外部消息 handler 注册（供 FriendProvider / ConversationProvider 订阅） =====
  final Map<String, List<void Function(Map<String, dynamic>)>> _externalHandlers = {};

  /// 注册外部消息处理器（如 friend_request, private_message 等）
  void registerHandler(String type, void Function(Map<String, dynamic>) handler) {
    _externalHandlers.putIfAbsent(type, () => []).add(handler);
  }

  /// 移除外部消息处理器
  void removeHandler(String type, void Function(Map<String, dynamic>) handler) {
    _externalHandlers[type]?.remove(handler);
  }

  // ===== 回调 =====

  /// 消息列表变化后回调（用于触发 notifyListeners）
  VoidCallback? onMessagesChanged;

  /// 在线人数变化回调
  void Function(int count)? onOnlineCountChanged;

  // ===== 消息列表操作 =====

  /// 设置消息列表（加载历史时使用）
  void setMessages(List<ChatMessageModel> msgs) {
    _messages.clear();
    _messages.addAll(msgs);
    _messageIds.clear();
    for (final msg in _messages) {
      if (msg.id != null) _messageIds.add(msg.id!);
    }
  }

  /// 在头部插入去重后的消息（loadMore 时使用）
  void insertMessagesAtStart(List<ChatMessageModel> msgs) {
    final newMessages = msgs.where((msg) {
      if (msg.id == null) return true;
      return !_messageIds.contains(msg.id);
    }).toList();

    for (final msg in newMessages) {
      if (msg.id != null) _messageIds.add(msg.id!);
    }
    _messages.insertAll(0, newMessages);
  }

  /// 清空消息
  void clearMessages() {
    _messages.clear();
    _messageIds.clear();
  }

  // ===== 消息路由 =====

  /// 处理从 WsChatManager 传来的已解析消息
  void handleMessage(Map<String, dynamic> data) {
    final type = data['type'];

    switch (type) {
      case 'message':
        _handleChatMessage(data);
        break;

      case 'online_count':
        onOnlineCountChanged?.call(data['online_count'] ?? 0);
        break;

      case 'auth_success':
        // 由 WsChatManager 内部处理状态，这里仅做透传（如果外部需要）
        break;

      case 'auth_fail':
        debugPrint('[WS] Auth failed: ${data['msg']}');
        break;

      case 'error':
        debugPrint('[WS] Server error: ${data['msg']} code=${data['error_code']} client_msg_id=${data['client_msg_id']}');
        // 透传到外部 handler，便于私聊/群聊页面定位到对应乐观消息并标记失败
        _dispatchToExternalHandlers('error', data);
        break;

      // ===== 红包消息 — 公共聊天室当作普通消息处理 =====
      case 'red_packet':
        _handleRedPacketMessage(data);
        break;

      case 'red_packet_claimed':
        _dispatchToExternalHandlers(type, data);
        break;

      // ===== 好友 & 私聊 & 群聊 新消息类型 =====
      case 'friend_request':
      case 'friend_accepted':
      case 'private_message':
      case 'group_message':
        debugPrint('[WS] Dispatching $type to external handlers');
        _dispatchToExternalHandlers(type, data);
        break;

      default:
        debugPrint('[WS] Unknown message type: $type');
        _dispatchToExternalHandlers(type, data);
        break;
    }
  }

  // ===== 内部实现 =====

  void _handleChatMessage(Map<String, dynamic> data) {
    final msg = ChatMessageModel.fromJson(data);

    // 去重：防止重连后收到重复消息
    if (msg.id != null && _messageIds.contains(msg.id)) {
      debugPrint('[WS] Duplicate message id=${msg.id}, skip');
      return;
    }
    if (msg.id != null) _messageIds.add(msg.id!);

    _messages.add(msg);
    _trimMessages();
    onMessagesChanged?.call();
  }

  void _handleRedPacketMessage(Map<String, dynamic> data) {
    // 兼容处理：确保 msg_type 和 content 字段存在
    data['msg_type'] ??= 'red_packet';
    if (data['content'] == null || data['content'] == '') {
      data['content'] = jsonEncode({
        'red_packet_id': data['red_packet_id'] ?? 0,
        'greeting': data['greeting'] ?? '',
        'sender_vip_level': data['sender_vip_level'] ?? 'normal',
      });
    }
    final rpMsg = ChatMessageModel.fromJson(data);
    if (rpMsg.id != null && _messageIds.contains(rpMsg.id)) return;
    if (rpMsg.id != null) _messageIds.add(rpMsg.id!);
    _messages.add(rpMsg);
    _trimMessages();
    onMessagesChanged?.call();

    // 同时分发给外部 handler
    _dispatchToExternalHandlers('red_packet', data);
  }

  /// 限制内存中的消息数量
  void _trimMessages() {
    if (_messages.length > maxMessageCacheSize) {
      final removed = _messages.removeAt(0);
      if (removed.id != null) _messageIds.remove(removed.id);
      hasMore = true;
    }
  }

  /// 分发消息到外部 handler
  void _dispatchToExternalHandlers(String? type, Map<String, dynamic> data) {
    if (type == null) return;
    final handlers = _externalHandlers[type];
    if (handlers != null) {
      for (final handler in handlers) {
        try {
          handler(data);
        } catch (e) {
          debugPrint('[WS] External handler error for $type: $e');
        }
      }
    }
  }
}
