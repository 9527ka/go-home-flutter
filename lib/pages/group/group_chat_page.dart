import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_config_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/conversation_provider.dart';
import '../../models/chat_message.dart';
import '../../models/group.dart';
import '../../models/group_member.dart';
import '../../services/chat_service.dart';
import '../../services/group_service.dart';
import '../../services/wallet_service.dart';
import '../../utils/url_helper.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/chat/voice_record_overlay.dart';
import '../../widgets/chat/date_separator.dart';
import '../../widgets/chat/media_panel.dart';
import '../../widgets/chat/chat_input_bar.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/chat/bubble_content.dart';
import '../../widgets/chat/message_actions.dart';
import '../friend/user_profile_page.dart';
import '../wallet/red_packet_send_dialog.dart';
import '../wallet/red_packet_open_dialog.dart';
import 'group_message_search_page.dart';
import 'group_mention_picker.dart';

class GroupChatPage extends StatefulWidget {
  final int groupId;

  const GroupChatPage({super.key, required this.groupId});

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();

  /// 清除指定群的进程内聊天缓存（外部：清空聊天记录时调用）
  static void invalidateCache(int groupId) {
    _GroupChatPageState._groupChatCaches.remove(groupId);
  }

  /// 清除所有群聊缓存（登出 / 切换账号时调用）
  static void invalidateAllCaches() {
    _GroupChatPageState._groupChatCaches.clear();
  }
}

class _GroupChatPageState extends State<GroupChatPage> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _groupService = GroupService();
  final _chatService = ChatService();
  final _imagePicker = ImagePicker();
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();

  GroupModel? _group;
  GroupMemberModel? _myMember; // 当前用户在本群的成员信息（用于判定角色 & 禁言）
  final Map<int, String> _aliasMap = {}; // userId -> 群内昵称（alias）
  final List<GroupMemberModel> _allMembers = []; // 完整成员列表（用于 @ 选择）
  // 已 @ 的成员：插入文本时记录，发送时附带 mentions；删除字符时按需清理
  final Map<int, String> _pendingMentions = {}; // userId -> 显示名（不含 @）
  String _lastInputText = ''; // 上一次输入文本（用于检测 @ 触发）
  bool _mentionPickerOpen = false;

  // ===== 进程内消息缓存（页面导航不丢失，进程被杀掉后自动清空） =====
  // 外部通过 GroupChatPage.invalidateCache / invalidateAllCaches 访问
  static final Map<int, _GroupChatCache> _groupChatCaches = {};

  final List<ChatMessageModel> _messages = [];
  bool _needsAutoScroll = true;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _showEmojiPicker = false;
  bool _showMediaPanel = false;
  bool _isUploading = false;
  bool _hasInputText = false;
  final Set<int> _claimingRedPacketIds = {};
  final Set<int> _claimedRedPacketIds = {};

  // 语音模式 & 录音状态
  bool _voiceMode = false;
  bool _isRecording = false;
  bool _cancellingVoice = false;
  int _recordDuration = 0;
  Timer? _recordTimer;
  Timer? _amplitudeTimer;
  List<double> _amplitudes = [];
  OverlayEntry? _recordOverlay;

  // 语音上传占位
  int? _uploadingVoiceDuration;

  // 语音播放
  int? _playingMsgId;

  @override
  void initState() {
    super.initState();
    // 标记当前活跃会话（防止未读数递增）
    final convProvider = context.read<ConversationProvider>();
    convProvider.setCurrentUserId(context.read<AuthProvider>().user?.id);
    convProvider.setActiveConversation(widget.groupId, 'group');
    _loadGroupInfo();
    _loadMessages();
    _registerWsHandler();

    _msgCtrl.addListener(() {
      final hasText = _msgCtrl.text.trim().isNotEmpty;
      if (hasText != _hasInputText) {
        setState(() => _hasInputText = hasText);
      }
      // 清理已删除的 @mention（用户手动删除 "@xxx " 时，不应再 mention 该人）
      if (_pendingMentions.isNotEmpty) {
        final text = _msgCtrl.text;
        _pendingMentions.removeWhere((_, name) => !text.contains('@$name '));
      }
      _maybeTriggerMentionPicker();
    });

    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels <= 50 && !_isLoadingMore && _hasMore) {
        _loadMore();
      }
    });
  }

  @override
  void deactivate() {
    // 在 deactivate 中清除活跃会话标记，此时 context 仍有效
    context.read<ConversationProvider>().clearActiveConversation();
    super.deactivate();
  }

  @override
  void dispose() {
    // 先保存消息进程内缓存（下次进入直接复用，无需重拉）
    _saveChatCache();
    _removeRecordOverlay();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _recordTimer?.cancel();
    _amplitudeTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _unregisterWsHandler();
    super.dispose();
  }

  // ===== WebSocket =====

  void _registerWsHandler() {
    final chatProvider = context.read<ChatProvider>();
    chatProvider.registerHandler('group_message', _onGroupMessage);
    chatProvider.registerHandler('group_event', _onGroupEvent);
  }

  void _unregisterWsHandler() {
    try {
      final chatProvider = context.read<ChatProvider>();
      chatProvider.removeHandler('group_message', _onGroupMessage);
      chatProvider.removeHandler('group_event', _onGroupEvent);
    } catch (_) {}
  }

  void _onGroupMessage(Map<String, dynamic> data) {
    final groupId = data['group_id'] as int? ?? 0;
    if (groupId != widget.groupId) return;

    // 跳过自己发的乐观消息（通过 WebSocket 回传的）
    final fromId = data['user_id'] ?? data['from_id'] ?? 0;
    final currentUserId = context.read<AuthProvider>().user?.id;
    if (fromId == currentUserId) return;

    final msg = ChatMessageModel.fromJson(data);
    if (mounted) {
      setState(() => _messages.add(msg));
      _scrollToBottomIfNeeded();
    }
  }

  /// 群事件实时推送（如全员禁言开关）
  void _onGroupEvent(Map<String, dynamic> data) {
    final groupId = data['group_id'] as int? ?? 0;
    if (groupId != widget.groupId || !mounted || _group == null) return;

    final event = (data['event'] ?? '') as String;
    if (event == 'all_muted_changed') {
      final allMuted = (data['all_muted'] ?? 0) as int;
      setState(() {
        _group = _group!.copyWith(allMuted: allMuted);
      });
      final l = AppLocalizations.of(context)!;
      Fluttertoast.showToast(
        msg: allMuted == 1
            ? l.get('group_all_mute_on_success')
            : l.get('group_all_mute_off_success'),
      );
    }
  }

  // ===== 数据加载 =====

  Future<void> _loadGroupInfo() async {
    try {
      final data = await _groupService.getGroupDetail(widget.groupId);
      if (data != null && mounted) {
        final memberList = data['members'] as List? ?? [];
        // 找出当前用户在本群的 member 记录 + 构建 alias 映射 + 完整成员列表
        final currentUserId = context.read<AuthProvider>().user?.id;
        GroupMemberModel? myMember;
        final aliasMap = <int, String>{};
        final members = <GroupMemberModel>[];
        for (final raw in memberList) {
          if (raw is Map<String, dynamic>) {
            final m = GroupMemberModel.fromJson(raw);
            members.add(m);
            if (m.alias.isNotEmpty) aliasMap[m.userId] = m.alias;
            if (m.userId == currentUserId) myMember = m;
          }
        }

        setState(() {
          _group = GroupModel.fromJson(data['group'] ?? data);
          _myMember = myMember;
          _aliasMap
            ..clear()
            ..addAll(aliasMap);
          _allMembers
            ..clear()
            ..addAll(members);
        });
        // 更新群成员头像到会话缓存
        if (memberList.isNotEmpty) {
          final avatars = memberList.map((e) => '${(e as Map)['avatar'] ?? (e['user'] as Map?)?['avatar'] ?? ''}').take(9).toList();
          final names = memberList.map((e) => '${(e as Map)['nickname'] ?? (e['user'] as Map?)?['nickname'] ?? ''}').take(9).toList();
          context.read<ConversationProvider>().setGroupMemberAvatars(widget.groupId, avatars, names);
        }
      }
    } catch (e) {
      debugPrint('[GroupChat] loadGroupInfo error: $e');
    }
  }

  /// 检测是否新输入了 `@` 字符（且光标紧跟其后），自动弹出成员选择
  void _maybeTriggerMentionPicker() {
    final text = _msgCtrl.text;
    final selection = _msgCtrl.selection;

    // 仅当文本"新增"了一个 @ 时触发（避免循环触发）
    if (text.length == _lastInputText.length + 1 &&
        selection.isCollapsed &&
        selection.baseOffset > 0 &&
        text[selection.baseOffset - 1] == '@' &&
        !_mentionPickerOpen) {
      _lastInputText = text;
      // 异步触发，避免在监听器中直接 showModal
      WidgetsBinding.instance.addPostFrameCallback((_) => _showMentionPicker(removeAtSign: true));
      return;
    }
    _lastInputText = text;
  }

  /// 弹出 @ 成员选择器
  /// [removeAtSign] 为 true 时，从光标前删除一个 `@` 字符（手动按按钮触发不需要）
  Future<void> _showMentionPicker({bool removeAtSign = false}) async {
    if (_mentionPickerOpen) return;
    if (_allMembers.isEmpty) return;
    final myId = context.read<AuthProvider>().user?.id;
    _mentionPickerOpen = true;
    final picked = await showModalBottomSheet<GroupMemberModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GroupMentionPicker(
        members: _allMembers,
        excludeUserId: myId,
      ),
    );
    _mentionPickerOpen = false;
    if (!mounted) return;

    // 不论是否选中，先处理触发字符的 @
    final selection = _msgCtrl.selection;
    String text = _msgCtrl.text;
    int cursor = selection.isValid ? selection.baseOffset : text.length;
    if (removeAtSign && cursor > 0 && cursor <= text.length && text[cursor - 1] == '@') {
      text = text.substring(0, cursor - 1) + text.substring(cursor);
      cursor -= 1;
    }

    if (picked != null) {
      final displayName = picked.alias.isNotEmpty ? picked.alias : picked.userNickname;
      final insert = '@$displayName ';
      final before = text.substring(0, cursor);
      final after = text.substring(cursor);
      text = '$before$insert$after';
      cursor += insert.length;
      _pendingMentions[picked.userId] = displayName;
    }

    _lastInputText = text;
    _msgCtrl.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor),
    );
  }

  /// 当前用户是否被禁止发送消息，返回禁止原因（null 表示允许发送）
  String? _getSendBlockReason(AppLocalizations l) {
    final g = _group;
    if (g == null) return null;
    if (g.isBanned) return l.get('chat_group_banned');
    final isAdmin = _myMember?.isAdmin == true;
    if (g.isAllMuted && !isAdmin) return l.get('chat_group_all_muted');
    if (_myMember?.isMuted == true) return l.get('chat_member_muted');
    return null;
  }

  /// 本地"清空聊天记录"的时间戳（毫秒），早于此时间的消息将被过滤
  Future<int> _loadClearedAt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('group_cleared_at_${widget.groupId}') ?? 0;
  }

  bool _isAfterCleared(ChatMessageModel msg, int clearedAt) {
    if (clearedAt == 0) return true;
    try {
      return DateTime.parse(msg.createdAt).millisecondsSinceEpoch > clearedAt;
    } catch (_) {
      return true;
    }
  }

  Future<void> _loadMessages() async {
    // 优先使用进程内缓存：页面导航来回不重新请求，仅进程被杀掉或清空聊天记录后才重新加载
    final cache = _groupChatCaches[widget.groupId];
    if (cache != null) {
      setState(() {
        _messages
          ..clear()
          ..addAll(cache.messages);
        _hasMore = cache.hasMore;
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(animate: false);
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final clearedAt = await _loadClearedAt();
      final data = await _groupService.getMessages(
        groupId: widget.groupId,
        limit: 50,
      );
      if (mounted) {
        final list = data['list'] as List? ?? [];
        final parsed = list
            .map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
            .where((m) => _isAfterCleared(m, clearedAt))
            .toList();
        setState(() {
          _messages.clear();
          _messages.addAll(parsed);
          _hasMore = data['has_more'] == true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom(animate: false);
        });
      }
    } catch (e) {
      debugPrint('[GroupChat] loadMessages error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 保存当前消息到进程内缓存
  void _saveChatCache() {
    if (_messages.isNotEmpty) {
      _groupChatCaches[widget.groupId] = _GroupChatCache(
        messages: List.of(_messages),
        hasMore: _hasMore,
      );
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _messages.isEmpty) return;
    _isLoadingMore = true;

    final prevMaxExtent =
        _scrollCtrl.hasClients ? _scrollCtrl.position.maxScrollExtent : 0.0;

    try {
      final firstMsgId = _messages.first.id;
      final clearedAt = await _loadClearedAt();
      final data = await _groupService.getMessages(
        groupId: widget.groupId,
        beforeId: firstMsgId,
        limit: 50,
      );
      if (mounted) {
        final list = data['list'] as List? ?? [];
        final older = list
            .map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
            .where((m) => _isAfterCleared(m, clearedAt))
            .toList();
        setState(() {
          _messages.insertAll(0, older);
          _hasMore = data['has_more'] == true;
        });

        if (_scrollCtrl.hasClients) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _scrollCtrl.hasClients) {
              final newMaxExtent = _scrollCtrl.position.maxScrollExtent;
              final diff = newMaxExtent - prevMaxExtent;
              if (diff > 0) {
                _scrollCtrl.jumpTo(_scrollCtrl.position.pixels + diff);
              }
            }
            _isLoadingMore = false;
          });
        } else {
          _isLoadingMore = false;
        }
      }
    } catch (e) {
      debugPrint('[GroupChat] loadMore error: $e');
      _isLoadingMore = false;
    }
  }

  void _scrollToBottom({bool animate = true}) {
    if (!_scrollCtrl.hasClients) return;
    if (animate) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else {
      _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
    }
  }

  void _scrollToBottomIfNeeded() {
    if (_needsAutoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  // ===== 发送消息 =====

  void _sendTextMessage() {
    final auth = context.read<AuthProvider>();
    final l = AppLocalizations.of(context)!;

    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.get('login_to_send')),
          action: SnackBarAction(
            label: l.get('login'),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
          ),
        ),
      );
      return;
    }

    final blockReason = _getSendBlockReason(l);
    if (blockReason != null) {
      Fluttertoast.showToast(msg: blockReason);
      return;
    }

    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    // 仅保留文本中仍存在 "@<name> " 的 mention（防止已删除）
    final activeMentions = <int>[];
    _pendingMentions.forEach((uid, name) {
      if (text.contains('@$name')) activeMentions.add(uid);
    });

    final chatProvider = context.read<ChatProvider>();
    chatProvider.sendGroupMessage(widget.groupId, text, mentions: activeMentions.isEmpty ? null : activeMentions);

    // 更新会话列表
    context.read<ConversationProvider>().onMessageSent(
          targetId: widget.groupId,
          targetType: 'group',
          content: text,
          name: _group?.name ?? '',
          avatar: _group?.avatar ?? '',
        );

    // 乐观本地添加
    final user = auth.user!;
    final localMsg = ChatMessageModel(
      userId: user.id,
      nickname: user.nickname,
      avatar: user.avatar,
      content: text,
      createdAt: DateTime.now().toIso8601String(),
      mentions: activeMentions,
    );
    setState(() => _messages.add(localMsg));
    _msgCtrl.clear();
    _pendingMentions.clear();
    _lastInputText = '';
    _scrollToBottomIfNeeded();
  }

  // ===== 多媒体发送 =====

  /// 发送媒体前检查是否被限制，被限制返回 true
  bool _blockIfRestricted() {
    final l = AppLocalizations.of(context)!;
    final reason = _getSendBlockReason(l);
    if (reason != null) {
      Fluttertoast.showToast(msg: reason);
      return true;
    }
    return false;
  }

  Future<void> _pickAndSendImage() async {
    if (_blockIfRestricted()) return;
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 80,
      );
      if (picked == null) return;
      await _uploadImageAndSend(picked);
    } catch (e) {
      debugPrint('[GroupChat] pickImage error: $e');
    }
  }

  Future<void> _takeAndSendPhoto() async {
    if (_blockIfRestricted()) return;
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 80,
      );
      if (picked == null) return;
      await _uploadImageAndSend(picked);
    } catch (e) {
      debugPrint('[GroupChat] takePhoto error: $e');
    }
  }

  Future<void> _pickAndSendVideo() async {
    if (_blockIfRestricted()) return;
    try {
      final picked = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      if (picked == null) return;
      await _uploadVideoAndSend(picked);
    } catch (e) {
      debugPrint('[GroupChat] pickVideo error: $e');
    }
  }

  Future<void> _uploadImageAndSend(XFile xFile) async {
    if (_isUploading) return;
    setState(() => _isUploading = true);
    try {
      final result = await _chatService.uploadImage(xFile);
      if (result != null && mounted) {
        _sendMediaLocal('image', result);
      } else if (mounted) {
        Fluttertoast.showToast(msg: 'Upload failed');
      }
    } catch (e) {
      debugPrint('[GroupChat] uploadImage error: $e');
      if (mounted) Fluttertoast.showToast(msg: 'Upload failed');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _uploadVideoAndSend(XFile xFile) async {
    if (_isUploading) return;
    setState(() => _isUploading = true);
    try {
      final result = await _chatService.uploadVideo(xFile);
      if (result != null && mounted) {
        _sendMediaLocal('video', result);
      } else if (mounted) {
        Fluttertoast.showToast(msg: 'Upload failed');
      }
    } catch (e) {
      debugPrint('[GroupChat] uploadVideo error: $e');
      if (mounted) Fluttertoast.showToast(msg: 'Upload failed');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _sendMediaLocal(String mediaType, Map<String, dynamic> result) {
    final chatProvider = context.read<ChatProvider>();
    chatProvider.sendGroupMediaMessage(
      groupId: widget.groupId,
      msgType: mediaType,
      mediaUrl: result['url'] ?? '',
      thumbUrl: result['thumb_url'] ?? '',
      mediaInfo: result['media_info'],
    );

    // 更新会话列表
    final l = AppLocalizations.of(context)!;
    String preview = mediaType == 'image'
        ? '[${l.get("image")}]'
        : mediaType == 'video'
            ? '[${l.get("video")}]'
            : '[${l.get("voice")}]';
    context.read<ConversationProvider>().onMessageSent(
          targetId: widget.groupId,
          targetType: 'group',
          content: preview,
          msgType: mediaType,
          name: _group?.name ?? '',
          avatar: _group?.avatar ?? '',
        );

    // 乐观本地添加
    final auth = context.read<AuthProvider>();
    final user = auth.user!;
    final localMsg = ChatMessageModel(
      userId: user.id,
      nickname: user.nickname,
      avatar: user.avatar,
      msgType: ChatMsgType.values.firstWhere(
        (e) => e.name == mediaType,
        orElse: () => ChatMsgType.text,
      ),
      mediaUrl: result['url'] ?? '',
      thumbUrl: result['thumb_url'] ?? '',
      content: '',
      createdAt: DateTime.now().toIso8601String(),
    );
    setState(() => _messages.add(localMsg));
    _scrollToBottomIfNeeded();
  }

  // ===== 微信风格录音：按住说话 / 松开发送 / 上滑取消 =====

  Future<void> _onVoiceStart() async {
    if (_isRecording) return;
    if (_blockIfRestricted()) return;
    if (!await _audioRecorder.hasPermission()) return;

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );

    if (!mounted) return;
    setState(() {
      _isRecording = true;
      _cancellingVoice = false;
      _recordDuration = 0;
      _amplitudes = [];
    });

    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _recordDuration++);
      _recordOverlay?.markNeedsBuild();
      if (_recordDuration >= 60) _onVoiceEnd();
    });

    _amplitudeTimer =
        Timer.periodic(const Duration(milliseconds: 100), (_) async {
      if (!mounted || !_isRecording) return;
      try {
        final amp = await _audioRecorder.getAmplitude();
        final normalized = ((amp.current + 50) / 50).clamp(0.0, 1.0);
        if (_amplitudes.length >= 30) _amplitudes.removeAt(0);
        _amplitudes.add(normalized);
        _recordOverlay?.markNeedsBuild();
      } catch (_) {}
    });

    _showRecordOverlay();
  }

  void _onVoiceMove(LongPressMoveUpdateDetails details) {
    final isCancelling = details.offsetFromOrigin.dy < -80;
    if (isCancelling != _cancellingVoice) {
      setState(() => _cancellingVoice = isCancelling);
      _recordOverlay?.markNeedsBuild();
    }
  }

  Future<void> _onVoiceEnd() async {
    _removeRecordOverlay();
    _recordTimer?.cancel();
    _recordTimer = null;
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;

    final path = await _audioRecorder.stop();
    final duration = _recordDuration;
    final wasCancelled = _cancellingVoice;

    setState(() {
      _isRecording = false;
      _cancellingVoice = false;
      _recordDuration = 0;
    });

    if (wasCancelled || path == null || duration < 1) return;

    setState(() => _uploadingVoiceDuration = duration);
    _needsAutoScroll = true;

    try {
      final result = await _chatService.uploadVoice(path);
      if (result != null && mounted) {
        _sendMediaLocal('voice', {
          ...result,
          'media_info': {'duration': duration},
        });
      } else if (mounted) {
        Fluttertoast.showToast(
            msg: AppLocalizations.of(context)!.get('upload_failed'));
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
            msg: AppLocalizations.of(context)!.get('upload_failed'));
      }
    } finally {
      if (mounted) setState(() => _uploadingVoiceDuration = null);
    }
  }

  void _onVoiceCancel() async {
    _removeRecordOverlay();
    _recordTimer?.cancel();
    _recordTimer = null;
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
    await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _cancellingVoice = false;
      _recordDuration = 0;
    });
  }

  // ===== 录音浮层 =====

  void _showRecordOverlay() {
    _removeRecordOverlay();
    _recordOverlay = OverlayEntry(builder: (_) => _buildRecordOverlay());
    Overlay.of(context).insert(_recordOverlay!);
  }

  void _removeRecordOverlay() {
    _recordOverlay?.remove();
    _recordOverlay = null;
  }

  Widget _buildRecordOverlay() {
    return VoiceRecordOverlay(
      isRecording: _isRecording,
      cancelling: _cancellingVoice,
      recordDuration: _recordDuration,
      amplitudes: _amplitudes,
    );
  }

  // ===== 红包 =====

  void _showRedPacketDialog() {
    if (_blockIfRestricted()) return;
    setState(() => _showMediaPanel = false);
    showDialog(
      context: context,
      builder: (_) =>
          RedPacketSendDialog(targetType: 3, targetId: widget.groupId),
    ).then((result) {
      if (result != null) {
        final chatProvider = context.read<ChatProvider>();
        final redPacketId = result is Map ? (result['id'] ?? 0) : 0;
        if (redPacketId > 0) {
          chatProvider.sendGroupRedPacketMessage(widget.groupId, redPacketId);
        }
      }
    });
  }

  Future<void> _showRedPacketOpenDialog(int redPacketId, String senderName,
      String senderAvatar, String greeting) async {
    if (_claimingRedPacketIds.contains(redPacketId)) return;
    _claimingRedPacketIds.add(redPacketId);

    try {
      bool alreadyClaimed = false;
      double claimedAmount = 0;
      try {
        final detail = await WalletService().getRedPacketDetail(redPacketId);
        if (detail != null && detail.hasClaimed) {
          alreadyClaimed = true;
          claimedAmount = detail.myClaim!.amount;
          if (!_claimedRedPacketIds.contains(redPacketId)) {
            setState(() => _claimedRedPacketIds.add(redPacketId));
          }
        }
      } catch (_) {}

      if (!mounted) return;

      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierColor: Colors.transparent,
        barrierDismissible: false,
        builder: (_) => RedPacketOpenDialog(
          redPacketId: redPacketId,
          senderName: senderName,
          senderAvatar: senderAvatar,
          greeting: greeting,
          alreadyClaimed: alreadyClaimed,
          claimedAmount: claimedAmount,
        ),
      );

      if (result != null && mounted) {
        if (result['claimed'] == true) {
          setState(() => _claimedRedPacketIds.add(redPacketId));
          final amount = result['amount'] as double? ?? 0;
          final l = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('${l.get("claimed")} \$${amount.toStringAsFixed(2)}'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
        Navigator.pushNamed(context, AppRoutes.redPacketDetail,
            arguments: redPacketId);
      }
    } finally {
      _claimingRedPacketIds.remove(redPacketId);
    }
  }

  // ===== 语音播放 =====

  Future<void> _playVoice(ChatMessageModel msg) async {
    final absUrl = UrlHelper.ensureAbsolute(msg.mediaUrl);

    if (_playingMsgId == msg.id) {
      await _audioPlayer.stop();
      setState(() => _playingMsgId = null);
      return;
    }

    if (!UrlHelper.isValidNetworkUrl(absUrl)) {
      debugPrint('[GroupChat] Invalid voice URL: ${msg.mediaUrl}');
      Fluttertoast.showToast(
          msg: AppLocalizations.of(context)!.get('play_voice_failed'));
      return;
    }

    try {
      setState(() => _playingMsgId = msg.id);
      await _audioPlayer.setUrl(absUrl);
      _audioPlayer.play();
      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (mounted) setState(() => _playingMsgId = null);
        }
      });
    } catch (e) {
      debugPrint('[GroupChat] playVoice error: $e, url: $absUrl');
      if (mounted) {
        setState(() => _playingMsgId = null);
        Fluttertoast.showToast(
            msg: AppLocalizations.of(context)!.get('play_voice_failed'));
      }
    }
  }

  void _showFullImage(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(imageUrl: url),
            ),
          ),
        ),
      ),
    );
  }

  void _playVideo(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _VideoPlayerScreen(url: url)),
    );
  }

  // ===== 长按消息菜单 =====

  void _showMessageActions(ChatMessageModel msg, bool isMe) {
    showMessageActions(
      context: context,
      msg: msg,
      isMe: isMe,
      onReport: () => _reportMessage(msg),
    );
  }

  void _reportMessage(ChatMessageModel msg) {
    final l = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.get('chat_report')),
        content: Text(l.get('report_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.get('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await _chatService.reportMessage(
                messageId: msg.id ?? 0,
                userId: msg.userId,
                reason: 4,
              );
              if (mounted) {
                Fluttertoast.showToast(
                  msg: success
                      ? l.get('report_success')
                      : l.get('network_error'),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerColor,
              foregroundColor: Colors.white,
            ),
            child: Text(l.get('confirm')),
          ),
        ],
      ),
    );
  }

  // ===== UI =====

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final currentUserId = context.read<AuthProvider>().user?.id;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(_group?.name ?? '...'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, size: 22),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GroupMessageSearchPage(
                    groupId: widget.groupId,
                    localMessages: List.of(_messages),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz, size: 24),
            onPressed: () {
              Navigator.pushNamed(
                context,
                AppRoutes.groupDetail,
                arguments: widget.groupId,
              );
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          setState(() {
            _showEmojiPicker = false;
            _showMediaPanel = false;
          });
        },
        child: Column(
          children: [
            // 消息列表
            Expanded(
              child: _isLoading && _messages.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primaryColor))
                  : _messages.isEmpty && _uploadingVoiceDuration == null
                      ? _buildEmpty(l)
                      : NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification is ScrollUpdateNotification) {
                              final maxScroll =
                                  _scrollCtrl.position.maxScrollExtent;
                              _needsAutoScroll =
                                  _scrollCtrl.position.pixels >=
                                      maxScroll - 100;
                            }
                            return false;
                          },
                          child: ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            itemCount: _messages.length +
                                (_uploadingVoiceDuration != null ? 1 : 0),
                            itemBuilder: (ctx, index) {
                              if (index >= _messages.length) {
                                return _buildUploadingVoiceBubble();
                              }
                              final msg = _messages[index];
                              Widget? dateSeparator;
                              if (index == 0 ||
                                  _shouldShowDateSeparator(index)) {
                                dateSeparator =
                                    _buildDateSeparator(msg.createdAt);
                              }
                              return Column(
                                children: [
                                  if (dateSeparator != null) dateSeparator,
                                  _buildMessageBubble(msg, currentUserId),
                                ],
                              );
                            },
                          ),
                        ),
            ),

            // 上传指示器
            if (_isUploading)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                        width: 14,
                        height: 14,
                        child:
                            CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('Uploading...',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textHint)),
                  ],
                ),
              ),

            // 受限提示横幅
            if (_getSendBlockReason(l) != null) _buildRestrictedBanner(l),

            // 输入区域
            _buildInputBar(l),

            // Emoji picker
            if (_showEmojiPicker)
              SizedBox(
                height: 260,
                child: EmojiPicker(
                  onEmojiSelected: (_, emoji) {
                    _msgCtrl.text += emoji.emoji;
                    _msgCtrl.selection = TextSelection.collapsed(
                        offset: _msgCtrl.text.length);
                  },
                  config: Config(
                    columns: 8,
                    emojiSizeMax: 22 *
                        (defaultTargetPlatform == TargetPlatform.iOS
                            ? 1.3
                            : 1.0),
                    initCategory: Category.SMILEYS,
                    indicatorColor: AppTheme.primaryColor,
                    iconColorSelected: AppTheme.primaryColor,
                    backspaceColor: AppTheme.primaryColor,
                  ),
                ),
              ),

            // 多媒体面板
            if (_showMediaPanel) _buildMediaPanel(l),
          ],
        ),
      ),
    );
  }

  // ===== 输入栏 =====

  Widget _buildInputBar(AppLocalizations l) {
    return ChatInputBar(
      controller: _msgCtrl,
      voiceMode: _voiceMode,
      showEmojiPicker: _showEmojiPicker,
      showMediaPanel: _showMediaPanel,
      isUploading: _isUploading,
      hasInputText: _hasInputText,
      onSend: _sendTextMessage,
      onToggleVoice: () {
        setState(() {
          _voiceMode = !_voiceMode;
          _showEmojiPicker = false;
          _showMediaPanel = false;
        });
      },
      onToggleEmoji: () {
        FocusScope.of(context).unfocus();
        setState(() {
          _showEmojiPicker = !_showEmojiPicker;
          _showMediaPanel = false;
        });
      },
      onToggleMedia: () {
        FocusScope.of(context).unfocus();
        setState(() {
          _showMediaPanel = !_showMediaPanel;
          _showEmojiPicker = false;
        });
      },
      onTapTextField: () {
        setState(() {
          _showEmojiPicker = false;
          _showMediaPanel = false;
        });
      },
      onVoiceStart: _onVoiceStart,
      onVoiceMove: _onVoiceMove,
      onVoiceEnd: _onVoiceEnd,
      onVoiceCancel: _onVoiceCancel,
      isRecording: _isRecording,
      cancellingVoice: _cancellingVoice,
    );
  }

  Widget _buildRestrictedBanner(AppLocalizations l) {
    final reason = _getSendBlockReason(l) ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFFFF7E0),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: Color(0xFFB45309)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              reason,
              style: const TextStyle(fontSize: 13, color: Color(0xFF92400E)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPanel(AppLocalizations l) {
    return MediaPanel(
      onPickImage: _pickAndSendImage,
      onTakePhoto: _takeAndSendPhoto,
      onPickVideo: _pickAndSendVideo,
      onSendRedPacket: context.read<AppConfigProvider>().walletEnabled
          ? _showRedPacketDialog
          : null,
      pickImageLabel: l.get('chat_album'),
      takePhotoLabel: l.get('take_photo'),
      pickVideoLabel: l.get('chat_video'),
      redPacketLabel: l.get('red_packet'),
    );
  }

  // ===== 消息气泡 =====

  Widget _buildMessageBubble(ChatMessageModel msg, int? currentUserId) {
    // 系统通知（"XXX 加入了群聊" 等）：居中灰字胶囊，无头像/昵称/时间
    if (msg.msgType == ChatMsgType.system) {
      return _buildSystemNotice(msg.content);
    }

    final isMe = currentUserId != null && msg.userId == currentUserId;
    // 群内昵称（alias）优先于用户原昵称
    final displayName = _aliasMap[msg.userId] ?? msg.nickname;

    return MessageBubble(
      nickname: displayName,
      timeText: _formatTime(msg.createdAt),
      isMe: isMe,
      avatar: AvatarWidget(avatarPath: msg.avatar, name: msg.nickname, size: 36, isOfficial: msg.isOfficialService),
      onLongPress: () => _showMessageActions(msg, isMe),
      onAvatarTap: isMe ? null : () => UserProfilePage.show(
        context,
        userId: msg.userId,
        nickname: msg.nickname,
        avatar: msg.avatar,
        userCode: msg.userCode,
        isOfficial: msg.isOfficialService,
      ),
      // 长按他人头像 → 直接在输入框插入 @该成员
      onAvatarLongPress: isMe ? null : () => _mentionUserDirectly(msg.userId, displayName),
      content: _buildBubbleContent(msg, isMe),
    );
  }

  /// 直接 @ 指定成员（长按头像触发，不走选择器）
  void _mentionUserDirectly(int userId, String displayName) {
    if (userId <= 0) return;
    final insert = '@$displayName ';
    final text = _msgCtrl.text;
    final sel = _msgCtrl.selection;
    final cursor = sel.isValid ? sel.baseOffset : text.length;
    final before = text.substring(0, cursor);
    final after = text.substring(cursor);
    final newText = '$before$insert$after';
    _pendingMentions[userId] = displayName;
    _lastInputText = newText;
    _msgCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor + insert.length),
    );
    // 自动聚焦输入框方便接着打字
    FocusScope.of(context).requestFocus(FocusNode());
  }

  Widget _buildBubbleContent(ChatMessageModel msg, bool isMe) {
    final isVoicePlaying = _playingMsgId == msg.id;

    int redPacketId = 0;
    String greeting = '';
    try {
      if (msg.content.startsWith('{')) {
        final data = jsonDecode(msg.content) as Map<String, dynamic>;
        redPacketId = data['red_packet_id'] ?? 0;
        greeting = data['greeting'] ?? '';
      }
    } catch (_) {}
    final hasClaimed = _claimedRedPacketIds.contains(redPacketId);

    return BubbleContent(
      msg: msg,
      isMe: isMe,
      onImageTap: () => _showFullImage(UrlHelper.ensureAbsolute(msg.mediaUrl)),
      onVideoTap: () => _playVideo(UrlHelper.ensureAbsolute(msg.mediaUrl)),
      onVoiceTap: () => _playVoice(msg),
      isVoicePlaying: isVoicePlaying,
      hasClaimed: hasClaimed,
      onRedPacketTap: () {
        if (redPacketId > 0) {
          _showRedPacketOpenDialog(redPacketId, msg.nickname, msg.avatar, greeting);
        }
      },
    );
  }

  Widget _buildUploadingVoiceBubble() {
    return UploadingVoiceBubble(duration: _uploadingVoiceDuration ?? 0);
  }

  /// 系统通知：居中灰字胶囊（"XXX 加入了群聊" 等）
  Widget _buildSystemNotice(String content) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            content,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textHint,
            ),
          ),
        ),
      ),
    );
  }

  // ===== 辅助方法 =====

  bool _shouldShowDateSeparator(int index) {
    if (index == 0) return true;
    try {
      final current = DateTime.parse(_messages[index].createdAt);
      final previous = DateTime.parse(_messages[index - 1].createdAt);
      return current.year != previous.year ||
          current.month != previous.month ||
          current.day != previous.day;
    } catch (e) {
      return false;
    }
  }

  Widget _buildDateSeparator(String dateStr) {
    return DateSeparator(dateStr: dateStr);
  }

  Widget _buildEmpty(AppLocalizations l) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.chat_bubble_outline_rounded,
                size: 30, color: AppTheme.primaryColor.withOpacity(0.5)),
          ),
          const SizedBox(height: 16),
          Text(l.get('chat_empty'),
              style: const TextStyle(
                  fontSize: 14, color: AppTheme.textHint)),
        ],
      ),
    );
  }

  String _formatTime(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final now = DateTime.now();
      if (dt.year == now.year &&
          dt.month == now.month &&
          dt.day == now.day) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }
}

/// 视频播放器
class _VideoPlayerScreen extends StatefulWidget {
  final String url;
  const _VideoPlayerScreen({required this.url});

  @override
  State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: _controller.value.isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}

/// 群聊进程内消息缓存（仅存活于内存，进程被杀掉后自动清空）
class _GroupChatCache {
  final List<ChatMessageModel> messages;
  final bool hasMore;
  _GroupChatCache({required this.messages, required this.hasMore});
}
