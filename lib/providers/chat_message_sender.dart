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

  /// 发送私聊文本消息
  void sendPrivateMessage(int toUserId, String content) {
    final text = content.trim();
    if (text.isEmpty) return;

    final filtered = ContentFilter.filter(text);

    if (!_ws.isAuthenticated) {
      debugPrint('[WS] Not authenticated, cannot send private message');
      return;
    }

    _ws.send({
      'type': 'private_message',
      'to_id': toUserId,
      'content': filtered,
    });
  }

  /// 发送私聊多媒体消息
  void sendPrivateMediaMessage({
    required int toUserId,
    required String msgType,
    required String mediaUrl,
    String thumbUrl = '',
    String content = '',
    Map<String, dynamic>? mediaInfo,
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
    _ws.send(data);
  }

  // ===== 群聊消息 =====

  /// 发送群聊文本消息
  void sendGroupMessage(int groupId, String content) {
    final text = content.trim();
    if (text.isEmpty) return;

    final filtered = ContentFilter.filter(text);

    if (!_ws.isAuthenticated) {
      debugPrint('[WS] Not authenticated, cannot send group message');
      return;
    }

    _ws.send({
      'type': 'group_message',
      'group_id': groupId,
      'content': filtered,
    });
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
  void sendPrivateRedPacketMessage(int toUserId, int redPacketId) {
    if (!_ws.isAuthenticated) return;
    _ws.send({
      'type': 'red_packet',
      'red_packet_id': redPacketId,
      'to_id': toUserId,
    });
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
