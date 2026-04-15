import 'package:flutter/foundation.dart';
import '../utils/content_filter.dart';
import 'chat_ws_manager.dart';

/// 封装所有消息发送方法。
///
/// 依赖 [WsChatManager] 来实际发送数据和判断连接状态。
class ChatMessageSender {
  final WsChatManager _ws;

  ChatMessageSender(this._ws);

  // ===== 公共聊天室消息 =====

  /// 发送文本消息（带敏感词过滤）
  void sendMessage(String content) {
    final text = content.trim();
    if (text.isEmpty) return;

    final filtered = ContentFilter.filter(text);

    if (!_ws.isAuthenticated) {
      if (_ws.isConnected ||
          _ws.connectionState == WsConnectionState.reconnecting) {
        _ws.enqueueMessage(filtered);
      } else {
        debugPrint('[WS] Not connected, cannot send');
      }
      return;
    }

    _ws.send({'type': 'message', 'content': filtered});
  }

  /// 发送多媒体消息（图片/视频/语音）
  void sendMediaMessage({
    required String msgType,
    required String mediaUrl,
    String thumbUrl = '',
    String content = '',
    Map<String, dynamic>? mediaInfo,
  }) {
    if (!_ws.isAuthenticated) {
      debugPrint('[WS] Not authenticated, cannot send media');
      return;
    }

    final data = <String, dynamic>{
      'type': 'message',
      'msg_type': msgType,
      'content': content,
      'media_url': mediaUrl,
      'thumb_url': thumbUrl,
    };
    if (mediaInfo != null) {
      data['media_info'] = mediaInfo;
    }
    _ws.send(data);
  }

  // ===== 私聊消息 =====

  /// 发送私聊文本消息。传入 [clientMsgId] 后服务端会在成功/失败回包中原样带回，
  /// 便于前端将乐观消息标为 sent/failed。
  void sendPrivateMessage(int toUserId, String content, {String? clientMsgId}) {
    final text = content.trim();
    if (text.isEmpty) return;

    final filtered = ContentFilter.filter(text);

    if (!_ws.isAuthenticated) {
      debugPrint('[WS] Not authenticated, cannot send private message');
      return;
    }

    final data = <String, dynamic>{
      'type': 'private_message',
      'to_id': toUserId,
      'content': filtered,
    };
    if (clientMsgId != null && clientMsgId.isNotEmpty) {
      data['client_msg_id'] = clientMsgId;
    }
    _ws.send(data);
  }

  /// 发送私聊多媒体消息
  void sendPrivateMediaMessage({
    required int toUserId,
    required String msgType,
    required String mediaUrl,
    String thumbUrl = '',
    String content = '',
    Map<String, dynamic>? mediaInfo,
    String? clientMsgId,
  }) {
    if (!_ws.isAuthenticated) {
      debugPrint('[WS] Not authenticated, cannot send private media');
      return;
    }

    final data = <String, dynamic>{
      'type': 'private_message',
      'to_id': toUserId,
      'msg_type': msgType,
      'content': content,
      'media_url': mediaUrl,
      'thumb_url': thumbUrl,
    };
    if (mediaInfo != null) {
      data['media_info'] = mediaInfo;
    }
    if (clientMsgId != null && clientMsgId.isNotEmpty) {
      data['client_msg_id'] = clientMsgId;
    }
    _ws.send(data);
  }

  // ===== 群聊消息 =====

  /// 发送群聊文本消息
  ///
  /// [mentions] 被@的用户 ID 列表（可选）
  void sendGroupMessage(int groupId, String content, {List<int>? mentions}) {
    final text = content.trim();
    if (text.isEmpty) return;

    final filtered = ContentFilter.filter(text);

    if (!_ws.isAuthenticated) {
      debugPrint('[WS] Not authenticated, cannot send group message');
      return;
    }

    final data = <String, dynamic>{
      'type': 'group_message',
      'group_id': groupId,
      'content': filtered,
    };
    if (mentions != null && mentions.isNotEmpty) {
      data['mentions'] = mentions;
    }
    _ws.send(data);
  }

  /// 发送群聊多媒体消息
  void sendGroupMediaMessage({
    required int groupId,
    required String msgType,
    required String mediaUrl,
    String thumbUrl = '',
    String content = '',
    Map<String, dynamic>? mediaInfo,
  }) {
    if (!_ws.isAuthenticated) {
      debugPrint('[WS] Not authenticated, cannot send group media');
      return;
    }

    final data = <String, dynamic>{
      'type': 'group_message',
      'group_id': groupId,
      'msg_type': msgType,
      'content': content,
      'media_url': mediaUrl,
      'thumb_url': thumbUrl,
    };
    if (mediaInfo != null) {
      data['media_info'] = mediaInfo;
    }
    _ws.send(data);
  }

  // ===== 红包消息 =====

  /// 发送红包消息到公共聊天室
  void sendRedPacketMessage(int redPacketId) {
    if (!_ws.isAuthenticated) {
      debugPrint('[WS] Not authenticated, cannot send red packet message');
      return;
    }
    _ws.send({'type': 'red_packet', 'red_packet_id': redPacketId});
  }

  /// 发送私聊红包消息
  void sendPrivateRedPacketMessage(int toUserId, int redPacketId, {String? clientMsgId}) {
    if (!_ws.isAuthenticated) return;
    final data = <String, dynamic>{
      'type': 'red_packet',
      'red_packet_id': redPacketId,
      'to_id': toUserId,
    };
    if (clientMsgId != null && clientMsgId.isNotEmpty) {
      data['client_msg_id'] = clientMsgId;
    }
    _ws.send(data);
  }

  /// 发送群聊红包消息
  void sendGroupRedPacketMessage(int groupId, int redPacketId) {
    if (!_ws.isAuthenticated) return;
    _ws.send({
      'type': 'red_packet',
      'red_packet_id': redPacketId,
      'group_id': groupId,
    });
  }
}
