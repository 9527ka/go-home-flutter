/// 会话模型 — 私聊或群聊会话列表项
class ConversationModel {
  final int targetId; // friend_id 或 group_id
  final String targetType; // 'private' 或 'group'
  final String name; // 好友昵称或群名
  final String avatar;
  final String lastMessage;
  final String lastMsgType; // text/image/video/voice
  final String lastMsgTime;
  final int unreadCount;
  final int userType; // 0=普通用户 1=官方客服
  final List<String> memberAvatars; // 群成员头像（用于九宫格头像）
  final List<String> memberNames; // 群成员名称（用于字母占位）

  ConversationModel({
    required this.targetId,
    required this.targetType,
    required this.name,
    this.avatar = '',
    this.lastMessage = '',
    this.lastMsgType = 'text',
    this.lastMsgTime = '',
    this.unreadCount = 0,
    this.userType = 0,
    this.memberAvatars = const [],
    this.memberNames = const [],
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    final rawAvatars = json['member_avatars'] as List?;
    final rawNames = json['member_names'] as List?;
    return ConversationModel(
      targetId: json['target_id'] ?? 0,
      targetType: json['target_type'] ?? 'private',
      name: json['name'] ?? '',
      avatar: json['avatar'] ?? '',
      lastMessage: json['last_message'] ?? '',
      lastMsgType: json['last_msg_type'] ?? 'text',
      lastMsgTime: json['last_msg_time'] ?? '',
      unreadCount: json['unread_count'] ?? 0,
      userType: json['user_type'] ?? 0,
      memberAvatars: rawAvatars?.map((e) => '$e').toList() ?? const [],
      memberNames: rawNames?.map((e) => '$e').toList() ?? const [],
    );
  }

  bool get isOfficialService => userType == 1;
  bool get isPrivate => targetType == 'private';
  bool get isGroup => targetType == 'group';
  bool get hasUnread => unreadCount > 0;

  /// 最后消息预览文本（需传入翻译函数以支持多语言）
  /// [tr] 接受 i18n key 返回翻译后的字符串，例如 l.get
  String lastMessagePreview(String Function(String key) tr) {
    switch (lastMsgType) {
      case 'image':
        return tr('media_image');
      case 'video':
        return tr('media_video');
      case 'voice':
        return tr('media_voice');
      case 'red_packet':
        return tr('media_red_packet');
      case 'voice_call':
        return tr('media_voice_call');
      default:
        // 兜底：如果 lastMsgType 未正确上报但 lastMessage 是红包 JSON，也识别为 [红包]
        if (lastMessage.startsWith('{') && lastMessage.contains('red_packet_id')) {
          return tr('media_red_packet');
        }
        return lastMessage;
    }
  }
}
