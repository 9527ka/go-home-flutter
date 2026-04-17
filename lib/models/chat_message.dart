import 'dart:convert';

/// 消息类型
enum ChatMsgType {
  text,
  image,
  video,
  voice,
  redPacket,
  voiceCall,
  contactCard, // 个人名片
  system, // 系统通知（"XXX 加入了群聊" 等），居中灰字渲染
}

/// 消息发送状态（主要用于私聊乐观消息）
enum SendStatus {
  sent,     // 已发送成功（或服务端历史消息）
  sending,  // 本地乐观消息，等待服务端回执
  failed,   // 服务端拒绝（非好友/被禁言等）
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
  final int userType; // 0=普通用户 1=官方客服
  final List<int> mentions; // 被@的用户 ID（仅群聊有效）

  /// 客户端生成的消息 ID（用于匹配乐观消息与服务端回执/错误）
  final String? clientMsgId;

  /// 发送状态（仅对本端发出的私聊消息有意义；从服务端收到的默认 sent）
  final SendStatus sendStatus;

  /// 发送失败的错误码（如 NOT_FRIEND）
  final String? errorCode;

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
    this.userType = 0,
    this.mentions = const [],
    this.clientMsgId,
    this.sendStatus = SendStatus.sent,
    this.errorCode,
  });

  ChatMessageModel copyWith({
    int? id,
    int? userId,
    String? userCode,
    String? nickname,
    String? avatar,
    ChatMsgType? msgType,
    String? content,
    String? mediaUrl,
    String? thumbUrl,
    Map<String, dynamic>? mediaInfo,
    String? createdAt,
    int? userType,
    List<int>? mentions,
    String? clientMsgId,
    SendStatus? sendStatus,
    String? errorCode,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userCode: userCode ?? this.userCode,
      nickname: nickname ?? this.nickname,
      avatar: avatar ?? this.avatar,
      msgType: msgType ?? this.msgType,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      thumbUrl: thumbUrl ?? this.thumbUrl,
      mediaInfo: mediaInfo ?? this.mediaInfo,
      createdAt: createdAt ?? this.createdAt,
      userType: userType ?? this.userType,
      mentions: mentions ?? this.mentions,
      clientMsgId: clientMsgId ?? this.clientMsgId,
      sendStatus: sendStatus ?? this.sendStatus,
      errorCode: errorCode ?? this.errorCode,
    );
  }

  /// 支持两种格式：
  /// 1. WebSocket 扁平格式: {user_id, nickname, avatar, msg_type, content, media_url, thumb_url, media_info, created_at}
  /// 2. REST API 嵌套格式: {user_id, content, created_at, user: {id, nickname, avatar}}
  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final fromUser = (json['from_user'] ?? json['fromUser']) as Map<String, dynamic>?;
    return ChatMessageModel(
      id: json['id'],
      userId: json['user_id'] ?? json['from_id'] ?? fromUser?['id'] ?? user?['id'] ?? 0,
      userCode: json['user_code'] ?? fromUser?['user_code'] ?? user?['user_code'] ?? '',
      nickname: json['nickname'] ?? json['from_nickname'] ?? fromUser?['nickname'] ?? user?['nickname'] ?? '',
      avatar: json['avatar'] ?? json['from_avatar'] ?? fromUser?['avatar'] ?? user?['avatar'] ?? '',
      msgType: parseMsgType(json['msg_type']),
      content: json['content'] ?? '',
      mediaUrl: json['media_url'] ?? '',
      thumbUrl: json['thumb_url'] ?? '',
      mediaInfo: _parseMediaInfo(json['media_info']),
      createdAt: json['created_at'] ?? '',
      userType: json['user_type'] ?? fromUser?['user_type'] ?? user?['user_type'] ?? 0,
      mentions: _parseMentions(json['mentions']),
      clientMsgId: json['client_msg_id'] as String?,
      sendStatus: SendStatus.sent,
    );
  }

  static Map<String, dynamic>? _parseMediaInfo(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
    return null;
  }

  static List<int> _parseMentions(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value.map((e) => (e is int) ? e : int.tryParse('$e') ?? 0).where((e) => e > 0).toList();
    }
    if (value is String && value.isNotEmpty) {
      // 后端可能直接序列化为 JSON 字符串
      try {
        final decoded = (value.startsWith('[')) ? value : '[$value]';
        // ignore: avoid_dynamic_calls
        final list = (decoded.isEmpty) ? <dynamic>[] : (List<dynamic>.from(_safeJsonDecode(decoded) ?? []));
        return list.map((e) => (e is int) ? e : int.tryParse('$e') ?? 0).where((e) => e > 0).toList();
      } catch (_) {
        return const [];
      }
    }
    return const [];
  }

  static dynamic _safeJsonDecode(String s) {
    try {
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }

  bool get isOfficialService => userType == 1;

  static ChatMsgType parseMsgType(dynamic value) {
    if (value is String) {
      switch (value) {
        case 'image':
          return ChatMsgType.image;
        case 'video':
          return ChatMsgType.video;
        case 'voice':
          return ChatMsgType.voice;
        case 'red_packet':
          return ChatMsgType.redPacket;
        case 'voice_call':
          return ChatMsgType.voiceCall;
        case 'contact_card':
          return ChatMsgType.contactCard;
        case 'system':
          return ChatMsgType.system;
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
      case ChatMsgType.redPacket:
        return 'red_packet';
      case ChatMsgType.voiceCall:
        return 'voice_call';
      case ChatMsgType.contactCard:
        return 'contact_card';
      case ChatMsgType.system:
        return 'system';
      case ChatMsgType.text:
        return 'text';
    }
  }

  // ===== 通话气泡（voice_call）辅助 =====

  /// 通话状态（仅 voiceCall 类型有效）：completed / declined / canceled / missed / busy
  String get callStatus => (mediaInfo?['status'] ?? '') as String;

  /// 通话时长（秒）；completed 时 > 0，其它状态为 0
  int get callDuration => (mediaInfo?['duration'] is int) ? mediaInfo!['duration'] as int : 0;

  /// 主叫 ID；用于判断"我是呼出方还是呼入方"
  int get callCallerId => (mediaInfo?['caller_id'] is int) ? mediaInfo!['caller_id'] as int : 0;

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'user_code': userCode,
    'nickname': nickname,
    'avatar': avatar,
    'msg_type': msgTypeStr,
    'content': content,
    'media_url': mediaUrl,
    'thumb_url': thumbUrl,
    'media_info': mediaInfo,
    'mentions': mentions,
    'user_type': userType,
    'created_at': createdAt,
  };

  /// 语音消息时长（秒）
  int get voiceDuration => mediaInfo?['duration'] ?? 0;

  /// 图片/视频宽高
  int get mediaWidth => mediaInfo?['width'] ?? 0;
  int get mediaHeight => mediaInfo?['height'] ?? 0;
}
