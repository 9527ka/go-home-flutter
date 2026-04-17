import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/conversation.dart';
import '../models/group_member.dart';
import '../providers/chat_provider.dart';
import '../services/group_service.dart';
import '../services/pm_service.dart';
import '../utils/in_app_notifier.dart';

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

  /// 是否已经从服务端加载过至少一次
  bool _loaded = false;

  /// 群成员头像缓存（groupId → avatars/names）
  final Map<int, List<String>> _groupAvatarCache = {};
  final Map<int, List<String>> _groupNameCache = {};
  final Set<int> _fetchingGroupIds = {};
  final GroupService _groupService = GroupService();

  /// 公共聊天室 group id（强制置顶，不允许取消）
  static const int kPublicRoomGroupId = 1;

  /// 置顶会话的 key 集合（格式："{targetType}_{targetId}"）
  final Set<String> _pinnedKeys = {};
  bool _pinnedLoaded = false;

  /// SharedPreferences 中的置顶索引 key（StringList，快速枚举所有置顶）
  static const String _prefsPinnedIndexKey = 'conv_pinned_keys';

  /// 免打扰会话 key 集合（格式同 _pinnedKeys）。内存状态保证 UI 立即响应。
  /// SharedPreferences 仍为主存储（key: `conv_mute_<type>_<id>`）。
  final Set<String> _mutedKeys = {};
  bool _mutedLoaded = false;

  String _pinnedKey(int targetId, String targetType) => '${targetType}_$targetId';

  /// 获取会话列表：公共聊天室（group id=1）始终最顶，其次置顶会话，其后普通会话
  List<ConversationModel> get conversations {
    ConversationModel? publicRoom;
    final pinned = <ConversationModel>[];
    final normal = <ConversationModel>[];
    for (final c in _conversations) {
      if (c.targetType == 'group' && c.targetId == kPublicRoomGroupId) {
        publicRoom = c;
      } else if (_pinnedKeys.contains(_pinnedKey(c.targetId, c.targetType))) {
        pinned.add(c);
      } else {
        normal.add(c);
      }
    }
    return [
      if (publicRoom != null) publicRoom,
      ...pinned,
      ...normal,
    ];
  }

  /// 判断会话是否已置顶
  bool isPinned(int targetId, String targetType) {
    return _pinnedKeys.contains(_pinnedKey(targetId, targetType));
  }

  /// 设置/取消置顶（持久化 + 立即重排）
  Future<void> setPinned(int targetId, String targetType, bool pinned) async {
    final key = _pinnedKey(targetId, targetType);
    final changed = pinned ? _pinnedKeys.add(key) : _pinnedKeys.remove(key);
    if (!changed) return;

    final prefs = await SharedPreferences.getInstance();
    // 兼容旧键：详情页开关当前直接读 conv_pin_<type>_<id>
    await prefs.setBool('conv_pin_${targetType}_$targetId', pinned);
    // 维护索引列表，便于 Provider 启动时快速枚举
    await prefs.setStringList(_prefsPinnedIndexKey, _pinnedKeys.toList());
    notifyListeners();
  }

  /// 首次加载置顶集合（从 SharedPreferences）
  Future<void> loadPinnedPreferences() async {
    if (_pinnedLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_prefsPinnedIndexKey) ?? const <String>[];
    _pinnedKeys
      ..clear()
      ..addAll(list);
    _pinnedLoaded = true;
    if (_pinnedKeys.isNotEmpty) notifyListeners();
  }

  /// 首次加载免打扰集合（遍历 SharedPreferences 所有 `conv_mute_*` 键）
  Future<void> loadMutedPreferences() async {
    if (_mutedLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    _mutedKeys.clear();
    for (final key in prefs.getKeys()) {
      if (key.startsWith('conv_mute_') && prefs.getBool(key) == true) {
        // conv_mute_<type>_<id> → "<type>_<id>"
        _mutedKeys.add(key.substring('conv_mute_'.length));
      }
    }
    _mutedLoaded = true;
    if (_mutedKeys.isNotEmpty) notifyListeners();
  }

  /// 同步判断会话是否免打扰（UI 可直接使用，会随 notifyListeners 刷新）
  bool isMuted(int targetId, String targetType) {
    return _mutedKeys.contains(_pinnedKey(targetId, targetType));
  }

  int get totalUnread => _totalUnread;
  bool get hasUnread => _totalUnread > 0;
  bool get isLoading => _isLoading;
  bool get isLoaded => _loaded;

  /// 翻译函数（由外部设置，用于通知栏本地化）
  String Function(String key)? _tr;

  /// 设置翻译函数
  void setTranslator(String Function(String key) tr) {
    _tr = tr;
  }

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
    // 首次绑定时加载置顶/免打扰集合（只读一次，之后通过 setPinned/setConversationMuted 维护）
    loadPinnedPreferences();
    loadMutedPreferences();
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
    var msgType = data['msg_type'] as String? ?? 'text';
    // 名片 JSON 自动识别为 contact_card 类型
    if (msgType == 'text' && content.startsWith('{') && content.contains('contact_card')) {
      msgType = 'contact_card';
    }
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
    var msgType = data['msg_type'] as String? ?? 'text';
    if (msgType == 'text' && content.startsWith('{') && content.contains('contact_card')) {
      msgType = 'contact_card';
    }
    final time = data['created_at'] as String? ?? DateTime.now().toIso8601String();

    // 群组名（如果服务端推送中包含的话）
    final groupName = data['group_name'] as String? ?? '';
    final groupAvatar = data['group_avatar'] as String? ?? '';

    // 自己发的消息或正在查看该群时不增加未读；系统通知也不计未读
    final fromId = data['from_id'] ?? data['user_id'] ?? 0;
    final bool isSentByMe = _currentUserId != null && fromId == _currentUserId;
    final bool isActive = _activeTargetId == groupId && _activeTargetType == 'group';
    final bool isSystem = msgType == 'system';
    final bool shouldIncrementUnread = !isSentByMe && !isActive && !isSystem;

    // 检查是否被 @：在 lastMessage 前缀加上 [有人@你] 标记
    String displayMessage = content;
    final mentions = data['mentions'];
    if (mentions is List && _currentUserId != null && mentions.contains(_currentUserId)) {
      final mentionLabel = _tr?.call('group_mentioned_you') ?? '[Someone @ you]';
      displayMessage = '$mentionLabel $content';
    }

    _updateConversation(
      targetId: groupId,
      targetType: 'group',
      name: groupName,
      avatar: groupAvatar,
      lastMessage: displayMessage,
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
      // 已有会话 — 更新最后消息，保留原有 name / avatar / userType / memberAvatars
      final old = _conversations[idx];
      final cachedAvatars = _groupAvatarCache[targetId];
      final cachedNames = _groupNameCache[targetId];
      final updated = ConversationModel(
        targetId: old.targetId,
        targetType: old.targetType,
        name: name.isNotEmpty ? name : old.name,
        avatar: avatar.isNotEmpty ? avatar : old.avatar,
        lastMessage: lastMessage,
        lastMsgType: lastMsgType,
        lastMsgTime: lastMsgTime,
        unreadCount: incrementUnread ? old.unreadCount + 1 : old.unreadCount,
        userType: old.userType,
        memberAvatars: cachedAvatars ?? old.memberAvatars,
        memberNames: cachedNames ?? old.memberNames,
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
          memberAvatars: _groupAvatarCache[targetId] ?? const [],
          memberNames: _groupNameCache[targetId] ?? const [],
        ),
      );
    }

    _totalUnread = _conversations.fold(0, (sum, c) => sum + c.unreadCount);
    notifyListeners();

    // 播放消息提示音 + 显示本地通知横幅（非免打扰 + 有新未读消息时）
    if (incrementUnread) {
      // 取置顶后会话的实际名称（已合并 fallback）
      final resolvedName = _conversations.first.name;
      _notifyNewMessage(targetId, targetType, resolvedName, lastMessage, lastMsgType);
    }
  }

  /// 播放提示音并显示通知横幅（检查免打扰状态）
  ///
  /// 三路通知：
  ///   1. 系统提示音 (`playMessageSound` MethodChannel — iOS 已实现，Android 待补)
  ///   2. 系统本地通知横幅 (`showLocalNotification` — 需用户授权)
  ///   3. 应用内横幅 (InAppNotifier — 前台兜底，不依赖权限/平台)
  void _notifyNewMessage(int targetId, String targetType, String senderName, String content, String msgType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final muted = prefs.getBool('conv_mute_${targetType}_$targetId') ?? false;
      if (muted) return;

      final tr = _tr;
      String body;
      switch (msgType) {
        case 'image':
          body = tr?.call('media_image') ?? '[Image]';
          break;
        case 'video':
          body = tr?.call('media_video') ?? '[Video]';
          break;
        case 'voice':
          body = tr?.call('media_voice') ?? '[Voice]';
          break;
        case 'red_packet':
          body = tr?.call('media_red_packet') ?? '[Red Packet]';
          break;
        case 'voice_call':
          body = tr?.call('media_voice_call') ?? '[Voice Call]';
          break;
        default:
          body = content;
      }
      final title = senderName.isNotEmpty
          ? senderName
          : (tr?.call('new_message') ?? 'New Message');

      // 应用内横幅（前台绝对可见，不依赖系统通知权限）
      InAppNotifier.show(title: title, body: body);

      // 系统提示音 + 本地通知（后台可见，前台走应用内横幅优先）
      const channel = MethodChannel('com.gohome/sound');
      await channel.invokeMethod('playMessageSound');
      await channel.invokeMethod('showLocalNotification', {
        'title': title,
        'body': body,
      });
    } catch (e) {
      debugPrint('[Conversation] _notifyNewMessage error: $e');
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

  /// 设置群成员头像（由外部页面更新）
  void setGroupMemberAvatars(int groupId, List<String> avatars, List<String> names) {
    _groupAvatarCache[groupId] = avatars;
    _groupNameCache[groupId] = names;
    // 同步到对应会话
    final idx = _conversations.indexWhere((c) => c.targetId == groupId && c.targetType == 'group');
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
        unreadCount: old.unreadCount,
        userType: old.userType,
        memberAvatars: avatars,
        memberNames: names,
      );
      notifyListeners();
    }
  }

  /// 异步拉取群成员头像（用于会话列表显示九宫格头像）
  Future<void> fetchGroupMemberAvatars(int groupId) async {
    if (_fetchingGroupIds.contains(groupId)) return;
    if (_groupAvatarCache.containsKey(groupId)) return;
    _fetchingGroupIds.add(groupId);
    try {
      final data = await _groupService.getGroupDetail(groupId);
      if (data != null) {
        final memberList = data['members'] as List? ?? [];
        final members = memberList
            .map((e) => GroupMemberModel.fromJson(e as Map<String, dynamic>))
            .toList();
        final avatars = members.map((m) => m.userAvatar).take(9).toList();
        final names = members.map((m) => m.displayName).take(9).toList();
        setGroupMemberAvatars(groupId, avatars, names);
      }
    } catch (e) {
      debugPrint('[Conversation] fetchGroupMemberAvatars error: $e');
    } finally {
      _fetchingGroupIds.remove(groupId);
    }
  }

  /// 仅在尚未加载过时从服务端拉取，已有数据则跳过
  Future<void> loadConversationsIfEmpty() async {
    if (_loaded && _conversations.isNotEmpty) return;
    await loadConversations();
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

      // 合并未读数策略：
      // - 本地=0（刚标记已读）→ 信任本地 0，不被服务端旧值覆盖
      // - 本地>服务端（WebSocket 实时递增）→ 用本地值
      // - 其他 → 用服务端值
      final merged = serverList.map((c) {
        final key = '${c.targetType}_${c.targetId}';
        final localUnread = localUnreadMap[key];
        final avatars = c.memberAvatars.isNotEmpty ? c.memberAvatars : (_groupAvatarCache[c.targetId] ?? const <String>[]);
        final names = c.memberNames.isNotEmpty ? c.memberNames : (_groupNameCache[c.targetId] ?? const <String>[]);
        final withAvatars = c.isGroup && (avatars.isNotEmpty || names.isNotEmpty)
            ? ConversationModel(
                targetId: c.targetId, targetType: c.targetType, name: c.name, avatar: c.avatar,
                lastMessage: c.lastMessage, lastMsgType: c.lastMsgType, lastMsgTime: c.lastMsgTime,
                unreadCount: c.unreadCount, userType: c.userType,
                memberAvatars: avatars, memberNames: names,
              )
            : c;
        if (localUnread == null) return withAvatars;
        if (localUnread == 0) {
          if (withAvatars.unreadCount == 0) return withAvatars;
          return ConversationModel(
            targetId: c.targetId, targetType: c.targetType, name: c.name, avatar: c.avatar,
            lastMessage: c.lastMessage, lastMsgType: c.lastMsgType, lastMsgTime: c.lastMsgTime,
            unreadCount: 0, userType: c.userType,
            memberAvatars: avatars, memberNames: names,
          );
        }
        if (localUnread > c.unreadCount) {
          return ConversationModel(
            targetId: c.targetId, targetType: c.targetType, name: c.name, avatar: c.avatar,
            lastMessage: c.lastMessage, lastMsgType: c.lastMsgType, lastMsgTime: c.lastMsgTime,
            unreadCount: localUnread, userType: c.userType,
            memberAvatars: avatars, memberNames: names,
          );
        }
        return withAvatars;
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
      _loaded = true;

      // 异步拉取群成员头像（不阻塞 UI）
      for (final c in _conversations) {
        if (c.isGroup && c.memberAvatars.isEmpty && !_groupAvatarCache.containsKey(c.targetId)) {
          fetchGroupMemberAvatars(c.targetId);
        }
      }
    } catch (e) {
      debugPrint('[Conversation] loadConversations error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 标记会话已读（本地先更新，再通知服务端，避免与 loadConversations 竞态）
  Future<void> markRead(int targetId, String targetType) async {
    // 先本地乐观更新，立即清除红点
    final idx = _conversations.indexWhere(
      (c) => c.targetId == targetId && c.targetType == targetType,
    );
    if (idx >= 0) {
      final old = _conversations[idx];
      if (old.unreadCount != 0) {
        _conversations[idx] = ConversationModel(
          targetId: old.targetId,
          targetType: old.targetType,
          name: old.name,
          avatar: old.avatar,
          lastMessage: old.lastMessage,
          lastMsgType: old.lastMsgType,
          lastMsgTime: old.lastMsgTime,
          unreadCount: 0,
          userType: old.userType,
          memberAvatars: old.memberAvatars,
          memberNames: old.memberNames,
        );
        _totalUnread = _conversations.fold(0, (sum, c) => sum + c.unreadCount);
        notifyListeners();
      }
    }

    // 再通知服务端（不阻塞 UI）
    try {
      if (targetType == 'private') {
        await _pmService.markRead(targetId);
      }
    } catch (e) {
      debugPrint('[Conversation] markRead server error: $e');
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

  /// 清空所有本地状态（切换账号/登出时调用）
  /// 防止新账号登录后看到上一个账号的会话
  void resetSession() {
    _conversations = [];
    _totalUnread = 0;
    _pinnedKeys.clear();
    _pinnedLoaded = false;
    _groupAvatarCache.clear();
    _groupNameCache.clear();
    _fetchingGroupIds.clear();
    _currentUserId = null;
    _activeTargetId = null;
    _activeTargetType = null;
    _loaded = false;
    _isLoading = false;
    notifyListeners();
  }

  // ===== 免打扰（本地偏好） =====

  /// 检查会话是否已开启免打扰
  Future<bool> isConversationMuted(int targetId, String targetType) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('conv_mute_${targetType}_$targetId') ?? false;
  }

  /// 切换会话免打扰（本地 + 同步服务端）
  Future<void> setConversationMuted(int targetId, String targetType, bool muted) async {
    final key = _pinnedKey(targetId, targetType);
    final changed = muted ? _mutedKeys.add(key) : _mutedKeys.remove(key);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('conv_mute_${targetType}_$targetId', muted);

    if (changed) notifyListeners();

    // 同步到服务端，服务端据此决定是否推送 APNs
    try {
      await _pmService.setMute(
        targetId: targetId,
        targetType: targetType,
        muted: muted,
      );
    } catch (e) {
      debugPrint('[Conversation] setMute sync error: $e');
    }
  }

  @override
  void dispose() {
    _unbindChatProvider();
    super.dispose();
  }
}
