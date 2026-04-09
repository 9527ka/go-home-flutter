import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import '../../config/currency.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_config_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/conversation_provider.dart';
import '../../models/chat_message.dart';
import '../../services/chat_service.dart';
import '../../services/pm_service.dart';
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
import 'private_chat_detail_page.dart';
import '../wallet/red_packet_send_dialog.dart';
import '../wallet/red_packet_open_dialog.dart';

/// 私聊聊天页面 — 与公共聊天室功能一致
/// [friendId] 好友用户 ID
/// [friendName] 好友昵称
/// [friendAvatar] 好友头像
/// [friendUserCode] 好友用户编号
class PrivateChatPage extends StatefulWidget {
  final int friendId;
  final String friendName;
  final String friendAvatar;
  final String friendUserCode;

  const PrivateChatPage({
    super.key,
    required this.friendId,
    required this.friendName,
    this.friendAvatar = '',
    this.friendUserCode = '',
  });

  @override
  State<PrivateChatPage> createState() => _PrivateChatPageState();
}

class _PrivateChatPageState extends State<PrivateChatPage> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _chatService = ChatService();
  final _pmService = PmService();
  final _imagePicker = ImagePicker();
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();

  final List<ChatMessageModel> _messages = [];
  final Set<int> _messageIds = {}; // 消息去重
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
  Timer? _amplitudeTimer; // 振幅采集定时器
  List<double> _amplitudes = []; // 声波振幅历史（用于绘制波形）
  double _currentAmplitude = 0; // 当前振幅 0~1
  OverlayEntry? _recordOverlay; // 录音浮层

  // 语音上传占位
  int? _uploadingVoiceDuration; // 非空表示正在上传语音，值为时长

  // 语音播放
  int? _playingMsgId;

  @override
  void initState() {
    super.initState();
    // 确保 WebSocket 已连接（引用计数，与公共聊天室共享）
    context.read<ChatProvider>().onPageEnter();
    // 标记当前活跃会话（防止未读数递增）
    final convProvider = context.read<ConversationProvider>();
    convProvider.setCurrentUserId(context.read<AuthProvider>().user?.id);
    convProvider.setActiveConversation(widget.friendId, 'private');
    _loadHistory();
    _registerWsHandler();

    _msgCtrl.addListener(() {
      final hasText = _msgCtrl.text.trim().isNotEmpty;
      if (hasText != _hasInputText) {
        setState(() => _hasInputText = hasText);
      }
    });

    _scrollCtrl.addListener(() {
      // 上拉加载更多
      if (_scrollCtrl.position.pixels <= 50 && !_isLoadingMore && _hasMore) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _removeRecordOverlay();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _recordTimer?.cancel();
    _amplitudeTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _unregisterWsHandler();
    // 清除活跃会话标记
    try {
      context.read<ConversationProvider>().clearActiveConversation();
    } catch (_) {}
    // 释放 WebSocket 引用计数
    try {
      context.read<ChatProvider>().onPageLeave();
    } catch (_) {}
    super.dispose();
  }

  /// 注册 WebSocket 私聊消息处理
  void _registerWsHandler() {
    final chatProvider = context.read<ChatProvider>();
    chatProvider.registerHandler('private_message', _onPrivateMessage);
  }

  void _unregisterWsHandler() {
    try {
      final chatProvider = context.read<ChatProvider>();
      chatProvider.removeHandler('private_message', _onPrivateMessage);
    } catch (_) {}
  }

  void _onPrivateMessage(Map<String, dynamic> data) {
    final fromId = data['from_id'] ?? data['user_id'] ?? 0;
    final toId = data['to_id'] ?? 0;
    final currentUserId = context.read<AuthProvider>().user?.id;

    // 只处理与当前好友相关的消息（对方发给我 或 我发给对方）
    final bool isFromFriend = fromId == widget.friendId;
    final bool isSentToFriend = currentUserId != null && fromId == currentUserId && toId == widget.friendId;
    if (!isFromFriend && !isSentToFriend) return;

    final msg = ChatMessageModel.fromJson(data);

    // 去重：防止与乐观本地消息或历史加载重复
    if (msg.id != null && _messageIds.contains(msg.id)) return;

    // 收到好友消息时，立即标记已读（返回会话列表不再显示红点）
    if (isFromFriend) {
      context.read<ConversationProvider>().markRead(widget.friendId, 'private');
    }

    if (mounted) {
      setState(() {
        if (msg.id != null) _messageIds.add(msg.id!);
        // 自己发的消息已经乐观添加过（无 id），用服务端回传替换
        if (isSentToFriend && msg.id != null) {
          // 尝试找到最后一条无 id 的本地乐观消息并替换
          final localIdx = _messages.lastIndexWhere(
            (m) => m.id == null && m.userId == currentUserId && m.content == msg.content,
          );
          if (localIdx >= 0) {
            _messages[localIdx] = msg;
            return;
          }
        }
        _messages.add(msg);
      });
      _scrollToBottomIfNeeded();
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      // 读取清空时间戳，过滤掉清空之前的消息
      final prefs = await SharedPreferences.getInstance();
      final clearedAtStr = prefs.getString('chat_cleared_at_${widget.friendId}');
      DateTime? clearedAt;
      if (clearedAtStr != null) {
        clearedAt = DateTime.tryParse(clearedAtStr);
      }

      final data = await _pmService.getHistory(friendId: widget.friendId, limit: 50);
      final list = data['list'] as List? ?? [];
      if (mounted) {
        setState(() {
          _messages.clear();
          _messageIds.clear();
          final loaded = list.map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>));
          for (final msg in loaded) {
            // 过滤清空之前的消息
            if (clearedAt != null && msg.createdAt.isNotEmpty) {
              final msgTime = DateTime.tryParse(msg.createdAt);
              if (msgTime != null && msgTime.isBefore(clearedAt)) continue;
            }
            if (msg.id != null) _messageIds.add(msg.id!);
            _messages.add(msg);
          }
          _hasMore = data['has_more'] == true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom(animate: false);
        });
      }
    } catch (e) {
      debugPrint('[PrivateChat] loadHistory error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _messages.isEmpty) return;
    _isLoadingMore = true;

    final prevMaxExtent = _scrollCtrl.hasClients ? _scrollCtrl.position.maxScrollExtent : 0.0;

    try {
      final firstMsgId = _messages.first.id;
      final data = await _pmService.getHistory(
        friendId: widget.friendId,
        beforeId: firstMsgId,
        limit: 50,
      );
      final list = data['list'] as List? ?? [];
      if (mounted) {
        final older = list
            .map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
            .where((msg) => msg.id == null || !_messageIds.contains(msg.id))
            .toList();
        setState(() {
          for (final msg in older) {
            if (msg.id != null) _messageIds.add(msg.id!);
          }
          _messages.insertAll(0, older);
          _hasMore = data['has_more'] == true;
        });

        // 保持滚动位置
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
      debugPrint('[PrivateChat] loadMore error: $e');
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

    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    final chatProvider = context.read<ChatProvider>();
    chatProvider.sendPrivateMessage(widget.friendId, text);

    // 更新会话列表
    context.read<ConversationProvider>().onMessageSent(
      targetId: widget.friendId,
      targetType: 'private',
      content: text,
      name: widget.friendName,
      avatar: widget.friendAvatar,
    );

    // 乐观本地添加
    final user = auth.user!;
    final localMsg = ChatMessageModel(
      userId: user.id,
      nickname: user.nickname,
      avatar: user.avatar,
      content: text,
      createdAt: DateTime.now().toIso8601String(),
    );
    setState(() {
      _messages.add(localMsg);
    });
    _msgCtrl.clear();
    _scrollToBottomIfNeeded();
  }

  Future<void> _pickAndSendImage() async {
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
      debugPrint('[PrivateChat] pickImage error: $e');
    }
  }

  Future<void> _takeAndSendPhoto() async {
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
      debugPrint('[PrivateChat] takePhoto error: $e');
    }
  }

  Future<void> _pickAndSendVideo() async {
    try {
      final picked = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      if (picked == null) return;
      await _uploadVideoAndSend(picked);
    } catch (e) {
      debugPrint('[PrivateChat] pickVideo error: $e');
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
      debugPrint('[PrivateChat] uploadImage error: $e');
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
      debugPrint('[PrivateChat] uploadVideo error: $e');
      if (mounted) Fluttertoast.showToast(msg: 'Upload failed');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _sendMediaLocal(String mediaType, Map<String, dynamic> result) {
    final chatProvider = context.read<ChatProvider>();
    chatProvider.sendPrivateMediaMessage(
      toUserId: widget.friendId,
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
      targetId: widget.friendId,
      targetType: 'private',
      content: preview,
      msgType: mediaType,
      name: widget.friendName,
      avatar: widget.friendAvatar,
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
    setState(() {
      _messages.add(localMsg);
    });
    _scrollToBottomIfNeeded();
  }

  // ===== 微信风格录音：按住说话 / 松开发送 / 上滑取消 =====

  Future<void> _onVoiceStart() async {
    if (_isRecording) return;

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
      _currentAmplitude = 0;
    });

    // 每秒计时
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _recordDuration++);
      _recordOverlay?.markNeedsBuild();
      if (_recordDuration >= 60) {
        _onVoiceEnd();
      }
    });

    // 每 100ms 采集振幅，用于声波动画
    _amplitudeTimer =
        Timer.periodic(const Duration(milliseconds: 100), (_) async {
      if (!mounted || !_isRecording) return;
      try {
        final amp = await _audioRecorder.getAmplitude();
        // amp.current 通常在 -60(安静) ~ 0(最大) dB 之间
        final normalized = ((amp.current + 50) / 50).clamp(0.0, 1.0);
        _currentAmplitude = normalized;
        if (_amplitudes.length >= 30) _amplitudes.removeAt(0);
        _amplitudes.add(normalized);
        _recordOverlay?.markNeedsBuild();
      } catch (_) {}
    });

    _showRecordOverlay();
  }

  void _onVoiceMove(LongPressMoveUpdateDetails details) {
    // 手指上移超过 80px 视为进入取消区域
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

    // 在列表中显示占位语音气泡（loading 状态）
    setState(() {
      _uploadingVoiceDuration = duration;
    });
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

  // ===== 录音浮层 Overlay =====

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
      currentAmplitude: _currentAmplitude,
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
        title: Text(widget.friendName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, size: 22),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PrivateChatDetailPage(
                    friendId: widget.friendId,
                    friendName: widget.friendName,
                    friendAvatar: widget.friendAvatar,
                    friendUserCode: widget.friendUserCode,
                    onClearMessages: () async {
                      // 持久化清空时间戳，下次加载历史时过滤
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString(
                        'chat_cleared_at_${widget.friendId}',
                        DateTime.now().toIso8601String(),
                      );
                      setState(() {
                        _messages.clear();
                        _messageIds.clear();
                      });
                    },
                  ),
                ),
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
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                  : _messages.isEmpty && _uploadingVoiceDuration == null
                      ? _buildEmpty(l)
                      : NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification is ScrollUpdateNotification) {
                              final maxScroll = _scrollCtrl.position.maxScrollExtent;
                              _needsAutoScroll = _scrollCtrl.position.pixels >= maxScroll - 100;
                            }
                            return false;
                          },
                          child: ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            itemCount: _messages.length + (_uploadingVoiceDuration != null ? 1 : 0),
                            itemBuilder: (ctx, index) {
                              // 末尾额外项：语音上传占位
                              if (index >= _messages.length) {
                                return _buildUploadingVoiceBubble();
                              }
                              final msg = _messages[index];
                              Widget? dateSeparator;
                              if (index == 0 || _shouldShowDateSeparator(index)) {
                                dateSeparator = _buildDateSeparator(msg.createdAt);
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
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('Uploading...', style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                  ],
                ),
              ),

            // 输入区域
            _buildInputBar(l),

            // Emoji picker
            if (_showEmojiPicker)
              SizedBox(
                height: 260,
                child: EmojiPicker(
                  onEmojiSelected: (_, emoji) {
                    _msgCtrl.text += emoji.emoji;
                    _msgCtrl.selection = TextSelection.collapsed(offset: _msgCtrl.text.length);
                  },
                  config: Config(
                    columns: 8,
                    emojiSizeMax: 28 * (defaultTargetPlatform == TargetPlatform.iOS ? 1.3 : 1.0),
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

  Widget _buildMediaPanel(AppLocalizations l) {
    return MediaPanel(
      onPickImage: _pickAndSendImage,
      onTakePhoto: _takeAndSendPhoto,
      onPickVideo: _pickAndSendVideo,
      onSendRedPacket: context.read<AppConfigProvider>().walletEnabled
          ? _showRedPacketDialog
          : null,
      pickImageLabel: l.get('media_image'),
      takePhotoLabel: l.get('media_camera'),
      pickVideoLabel: l.get('media_video'),
      redPacketLabel: l.get('red_packet'),
    );
  }

  // ===== 消息气泡 =====

  Widget _buildMessageBubble(ChatMessageModel msg, int? currentUserId) {
    final isMe = currentUserId != null && msg.userId == currentUserId;

    return MessageBubble(
      nickname: msg.nickname,
      timeText: _formatTime(msg.createdAt),
      isMe: isMe,
      avatar: AvatarWidget(avatarPath: msg.avatar, name: msg.nickname, size: 36),
      onLongPress: () => _showMessageActions(msg, isMe),
      onAvatarTap: isMe ? null : () => UserProfilePage.show(
        context,
        userId: msg.userId,
        nickname: msg.nickname,
        avatar: msg.avatar,
        userCode: msg.userCode,
      ),
      content: _buildBubbleContent(msg, isMe),
    );
  }

  /// 长按消息弹出操作菜单
  void _showMessageActions(ChatMessageModel msg, bool isMe) {
    showMessageActions(
      context: context,
      msg: msg,
      isMe: isMe,
      onReport: () => _reportMessage(msg),
    );
  }

  /// 举报消息
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
                  msg: success ? l.get('report_success') : l.get('network_error'),
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

  Future<void> _showRedPacketOpenDialog(int redPacketId, String senderName, String senderAvatar, String greeting) async {
    if (_claimingRedPacketIds.contains(redPacketId)) return;
    _claimingRedPacketIds.add(redPacketId);

    try {
      // 先查询红包详情，判断是否已领取
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
              content: Text('${l.get("claimed")} ${CurrencyConfig.format(amount)}'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
        Navigator.pushNamed(context, AppRoutes.redPacketDetail, arguments: redPacketId);
      }
    } finally {
      _claimingRedPacketIds.remove(redPacketId);
    }
  }

  void _showRedPacketDialog() {
    setState(() => _showMediaPanel = false);
    showDialog(
      context: context,
      builder: (_) => RedPacketSendDialog(targetType: 2, targetId: widget.friendId),
    ).then((result) {
      if (result != null) {
        final chatProvider = context.read<ChatProvider>();
        final redPacketId = result is Map ? (result['id'] ?? 0) : 0;
        if (redPacketId > 0) {
          chatProvider.sendPrivateRedPacketMessage(widget.friendId, redPacketId);
        }
      }
    });
  }

  Widget _buildUploadingVoiceBubble() {
    return UploadingVoiceBubble(duration: _uploadingVoiceDuration ?? 0);
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
      MaterialPageRoute(
        builder: (_) => _VideoPlayerScreen(url: url),
      ),
    );
  }

  Future<void> _playVoice(ChatMessageModel msg) async {
    final absUrl = UrlHelper.ensureAbsolute(msg.mediaUrl);

    // 如果点击正在播放的语音，则停止
    if (_playingMsgId == msg.id) {
      await _audioPlayer.stop();
      setState(() => _playingMsgId = null);
      return;
    }

    // URL 为空或无效，提示错误
    if (!UrlHelper.isValidNetworkUrl(absUrl)) {
      debugPrint('[PrivateChat] Invalid voice URL: ${msg.mediaUrl}');
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
      debugPrint('[PrivateChat] playVoice error: $e, url: $absUrl');
      if (mounted) {
        setState(() => _playingMsgId = null);
        Fluttertoast.showToast(
            msg: AppLocalizations.of(context)!.get('play_voice_failed'));
      }
    }
  }

  // ===== 辅助方法 =====

  bool _shouldShowDateSeparator(int index) {
    if (index == 0) return true;
    try {
      final current = DateTime.parse(_messages[index].createdAt);
      final previous = DateTime.parse(_messages[index - 1].createdAt);
      return current.year != previous.year || current.month != previous.month || current.day != previous.day;
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
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.chat_bubble_outline_rounded, size: 30, color: AppTheme.primaryColor.withOpacity(0.5)),
          ),
          const SizedBox(height: 16),
          Text(l.get('chat_empty'), style: const TextStyle(fontSize: 14, color: AppTheme.textHint)),
        ],
      ),
    );
  }

  String _formatTime(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }
}

/// 简单视频播放器
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
