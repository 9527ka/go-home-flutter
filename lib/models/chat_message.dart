/// 消息类型
enum ChatMsgType {
  text,
  image,
  video,
  voice,
}

class ChatMessageModel {
  final int? id;
  final int userId;
  final String userCode;
  final String nickname;
  final String avatar;
  final ChatMsgType msgType;
  final String content;
  final String mediaUrl;
  final String thumbUrl;
  final Map<String, dynamic>? mediaInfo;
  final String createdAt;

  ChatMessageModel({
    this.id,
    required this.userId,
    this.userCode = '',
    required this.nickname,
    this.avatar = '',
    this.msgType = ChatMsgType.text,
    required this.content,
    this.mediaUrl = '',
    this.thumbUrl = '',
    this.mediaInfo,
    required this.createdAt,
  });

  /// 支持两种格式：
  /// 1. WebSocket 扁平格式: {user_id, nickname, avatar, msg_type, content, media_url, thumb_url, media_info, created_at}
  /// 2. REST API 嵌套格式: {user_id, content, created_at, user: {id, nickname, avatar}}
  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return ChatMessageModel(
      id: json['id'],
      userId: json['user_id'] ?? user?['id'] ?? 0,
      userCode: json['user_code'] ?? user?['user_code'] ?? '',
      nickname: json['nickname'] ?? user?['nickname'] ?? '',
      avatar: json['avatar'] ?? user?['avatar'] ?? '',
      msgType: _parseMsgType(json['msg_type']),
      content: json['content'] ?? '',
      mediaUrl: json['media_url'] ?? '',
      thumbUrl: json['thumb_url'] ?? '',
      mediaInfo: json['media_info'] is Map<String, dynamic>
          ? json['media_info'] as Map<String, dynamic>
          : null,
      createdAt: json['created_at'] ?? '',
    );
  }

  static ChatMsgType _parseMsgType(dynamic value) {
    if (value is String) {
      switch (value) {
        case 'image':
          return ChatMsgType.image;
        case 'video':
          return ChatMsgType.video;
        case 'voice':
          return ChatMsgType.voice;
        default:
          return ChatMsgType.text;
      }
    }
    return ChatMsgType.text;
  }

  String get msgTypeStr {
    switch (msgType) {
      case ChatMsgType.image:
        return 'image';
      case ChatMsgType.video:
        return 'video';
      case ChatMsgType.voice:
        return 'voice';
      case ChatMsgType.text:
        return 'text';
    }
  }

  /// 语音消息时长（秒）
  int get voiceDuration => mediaInfo?['duration'] ?? 0;

  /// 图片/视频宽高
  int get mediaWidth => mediaInfo?['width'] ?? 0;
  int get mediaHeight => mediaInfo?['height'] ?? 0;
}
