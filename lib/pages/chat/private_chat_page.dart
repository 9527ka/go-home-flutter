import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
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
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../models/chat_message.dart';
import '../../services/chat_service.dart';
import '../../services/pm_service.dart';
import '../../widgets/avatar_widget.dart';
import '../friend/user_profile_page.dart';

/// 私聊聊天页面 — 与公共聊天室功能一致
/// [friendId] 好友用户 ID
/// [friendName] 好友昵称
/// [friendAvatar] 好友头像
class PrivateChatPage extends StatefulWidget {
  final int friendId;
  final String friendName;
  final String friendAvatar;

  const PrivateChatPage({
    super.key,
    required this.friendId,
    required this.friendName,
    this.friendAvatar = '',
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
  bool _needsAutoScroll = true;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _showEmojiPicker = false;
  bool _showMediaPanel = false;
  bool _isUploading = false;
  bool _hasInputText = false;

  // 语音模式 & 录音状态
  bool _voiceMode = false;
  bool _isRecording = false;
  bool _cancellingVoice = false;
  int _recordDuration = 0;
  Timer? _recordTimer;
  String? _recordPath;

  // 语音播放
  int? _playingMsgId;

  @override
  void initState() {
    super.initState();
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
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _unregisterWsHandler();
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
    // 只处理来自当前好友的消息
    final fromId = data['from_id'] ?? data['user_id'] ?? 0;
    if (fromId != widget.friendId) return;

    final msg = ChatMessageModel.fromJson(data);
    if (mounted) {
      setState(() {
        _messages.add(msg);
      });
      _scrollToBottomIfNeeded();
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final data = await _pmService.getHistory(friendId: widget.friendId, limit: 50);
      final list = data['list'] as List? ?? [];
      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(
            list.map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>)),
          );
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
            .toList();
        setState(() {
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

  Future<void> _uploadVoiceAndSend(String filePath) async {
    if (_isUploading) return;
    setState(() => _isUploading = true);
    try {
      final result = await _chatService.uploadVoice(filePath);
      if (result != null && mounted) {
        _sendMediaLocal('voice', result);
      } else if (mounted) {
        Fluttertoast.showToast(msg: 'Upload failed');
      }
    } catch (e) {
      debugPrint('[PrivateChat] uploadVoice error: $e');
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

  // ===== 语音录制 =====

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        _recordPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: _recordPath!,
        );
        setState(() {
          _isRecording = true;
          _recordDuration = 0;
        });
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (mounted) {
            setState(() => _recordDuration++);
            if (_recordDuration >= 60) {
              _stopRecordingAndSend();
            }
          }
        });
      }
    } catch (e) {
      debugPrint('[PrivateChat] startRecording error: $e');
    }
  }

  Future<void> _stopRecordingAndSend() async {
    _recordTimer?.cancel();
    try {
      final path = await _audioRecorder.stop();
      if (path != null && _recordDuration >= 1 && !_cancellingVoice) {
        await _uploadVoiceAndSend(path);
      }
    } catch (e) {
      debugPrint('[PrivateChat] stopRecording error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _cancellingVoice = false;
          _recordDuration = 0;
        });
      }
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    try {
      await _audioRecorder.stop();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isRecording = false;
        _cancellingVoice = false;
        _recordDuration = 0;
      });
    }
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
            icon: const Icon(Icons.person_outline, size: 22),
            onPressed: () {
              UserProfilePage.show(
                context,
                userId: widget.friendId,
                nickname: widget.friendName,
                avatar: widget.friendAvatar,
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
                  : _messages.isEmpty
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
                            itemCount: _messages.length,
                            itemBuilder: (ctx, index) {
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
    return Container(
      padding: EdgeInsets.only(
        left: 8, right: 8, top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 语音/键盘切换
          IconButton(
            icon: Icon(
              _voiceMode ? Icons.keyboard : Icons.mic_none,
              color: AppTheme.textSecondary,
              size: 24,
            ),
            onPressed: () {
              setState(() {
                _voiceMode = !_voiceMode;
                _showEmojiPicker = false;
                _showMediaPanel = false;
              });
            },
          ),

          // 输入区
          Expanded(
            child: _voiceMode
                ? _buildVoiceButton(l)
                : TextField(
                    controller: _msgCtrl,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 500,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: l.get('chat_input_hint'),
                      hintStyle: const TextStyle(color: AppTheme.textHint),
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      filled: true,
                      fillColor: AppTheme.scaffoldBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        _showEmojiPicker = false;
                        _showMediaPanel = false;
                      });
                    },
                  ),
          ),

          // Emoji 按钮
          if (!_voiceMode)
            IconButton(
              icon: Icon(
                _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined,
                color: AppTheme.textSecondary,
                size: 24,
              ),
              onPressed: () {
                FocusScope.of(context).unfocus();
                setState(() {
                  _showEmojiPicker = !_showEmojiPicker;
                  _showMediaPanel = false;
                });
              },
            ),

          // +多媒体 / 发送按钮
          if (_hasInputText)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5BA0E8), Color(0xFF4A90D9)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: IconButton(
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  onPressed: _sendTextMessage,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: AppTheme.textSecondary, size: 26),
              onPressed: () {
                FocusScope.of(context).unfocus();
                setState(() {
                  _showMediaPanel = !_showMediaPanel;
                  _showEmojiPicker = false;
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildVoiceButton(AppLocalizations l) {
    return GestureDetector(
      onLongPressStart: (_) => _startRecording(),
      onLongPressEnd: (_) {
        if (_cancellingVoice) {
          _cancelRecording();
        } else {
          _stopRecordingAndSend();
        }
      },
      onLongPressMoveUpdate: (details) {
        final dy = details.localOffsetFromOrigin.dy;
        setState(() => _cancellingVoice = dy < -50);
      },
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: _isRecording
              ? (_cancellingVoice ? AppTheme.dangerColor.withOpacity(0.1) : AppTheme.primaryColor.withOpacity(0.1))
              : AppTheme.scaffoldBg,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Center(
          child: Text(
            _isRecording
                ? (_cancellingVoice ? l.get('voice_cancel') : '${l.get('voice_recording')} ${_recordDuration}s')
                : l.get('voice_hold_to_talk'),
            style: TextStyle(
              fontSize: 14,
              color: _isRecording
                  ? (_cancellingVoice ? AppTheme.dangerColor : AppTheme.primaryColor)
                  : AppTheme.textSecondary,
              fontWeight: _isRecording ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaPanel(AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        border: Border(top: BorderSide(color: AppTheme.dividerColor, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _mediaItem(Icons.image_outlined, l.get('media_image'), _pickAndSendImage),
          _mediaItem(Icons.camera_alt_outlined, l.get('media_camera'), _takeAndSendPhoto),
          _mediaItem(Icons.videocam_outlined, l.get('media_video'), _pickAndSendVideo),
        ],
      ),
    );
  }

  Widget _mediaItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.scaffoldBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppTheme.textSecondary, size: 26),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textHint)),
        ],
      ),
    );
  }

  // ===== 消息气泡 =====

  Widget _buildMessageBubble(ChatMessageModel msg, int? currentUserId) {
    final isMe = currentUserId != null && msg.userId == currentUserId;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // 昵称 + 时间
          Padding(
            padding: EdgeInsets.only(bottom: 2, left: isMe ? 2 : 46, right: isMe ? 46 : 2),
            child: Text(
              '${msg.nickname}  ${_formatTime(msg.createdAt)}',
              style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMe) ...[
                // 暂时注释掉点击头像弹窗功能
                // GestureDetector(
                //   onTap: () => UserProfilePage.show(
                //     context,
                //     userId: msg.userId,
                //     nickname: msg.nickname,
                //     avatar: msg.avatar,
                //     userCode: msg.userCode,
                //   ),
                //   child: AvatarWidget(avatarPath: msg.avatar, name: msg.nickname, size: 36),
                // ),
                AvatarWidget(avatarPath: msg.avatar, name: msg.nickname, size: 36),
                const SizedBox(width: 8),
              ],
              Flexible(child: _buildBubbleContent(msg, isMe)),
              if (isMe) ...[
                const SizedBox(width: 8),
                AvatarWidget(avatarPath: msg.avatar, name: msg.nickname, size: 36),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBubbleContent(ChatMessageModel msg, bool isMe) {
    switch (msg.msgType) {
      case ChatMsgType.image:
        return _buildImageBubble(msg, isMe);
      case ChatMsgType.video:
        return _buildVideoBubble(msg, isMe);
      case ChatMsgType.voice:
        return _buildVoiceBubble(msg, isMe);
      default:
        return _buildTextBubble(msg, isMe);
    }
  }

  Widget _buildTextBubble(ChatMessageModel msg, bool isMe) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? AppTheme.primaryColor : AppTheme.cardBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isMe ? 14 : 4),
          topRight: Radius.circular(isMe ? 4 : 14),
          bottomLeft: const Radius.circular(14),
          bottomRight: const Radius.circular(14),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Text(
        msg.content,
        style: TextStyle(fontSize: 14, color: isMe ? Colors.white : AppTheme.textPrimary),
      ),
    );
  }

  Widget _buildImageBubble(ChatMessageModel msg, bool isMe) {
    final url = msg.thumbUrl.isNotEmpty ? msg.thumbUrl : msg.mediaUrl;
    return GestureDetector(
      onTap: () => _showFullImage(msg.mediaUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200),
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              width: 120, height: 120,
              color: AppTheme.scaffoldBg,
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            errorWidget: (_, __, ___) => Container(
              width: 120, height: 120,
              color: AppTheme.scaffoldBg,
              child: const Icon(Icons.broken_image, color: AppTheme.textHint),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoBubble(ChatMessageModel msg, bool isMe) {
    final thumbUrl = msg.thumbUrl.isNotEmpty ? msg.thumbUrl : '';
    return GestureDetector(
      onTap: () => _playVideo(msg.mediaUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (thumbUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: thumbUrl,
                width: 180, height: 120, fit: BoxFit.cover,
              )
            else
              Container(width: 180, height: 120, color: Colors.black87),
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceBubble(ChatMessageModel msg, bool isMe) {
    final duration = msg.mediaInfo?['duration'] ?? 0;
    final isPlaying = _playingMsgId == msg.id;
    final width = math.min(50.0 + duration * 4.0, 200.0);

    return GestureDetector(
      onTap: () => _playVoice(msg),
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primaryColor : AppTheme.cardBg,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isMe ? 14 : 4),
            topRight: Radius.circular(isMe ? 4 : 14),
            bottomLeft: const Radius.circular(14),
            bottomRight: const Radius.circular(14),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              size: 20,
              color: isMe ? Colors.white : AppTheme.primaryColor,
            ),
            const SizedBox(width: 6),
            Text(
              '${duration}s',
              style: TextStyle(
                fontSize: 13,
                color: isMe ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
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
    try {
      if (_playingMsgId == msg.id) {
        await _audioPlayer.stop();
        setState(() => _playingMsgId = null);
        return;
      }

      setState(() => _playingMsgId = msg.id);
      await _audioPlayer.setUrl(msg.mediaUrl);
      _audioPlayer.play();
      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (mounted) setState(() => _playingMsgId = null);
        }
      });
    } catch (e) {
      debugPrint('[PrivateChat] playVoice error: $e');
      if (mounted) setState(() => _playingMsgId = null);
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
    String label;
    try {
      final dt = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final msgDate = DateTime(dt.year, dt.month, dt.day);
      final l = AppLocalizations.of(context)!;

      if (msgDate == today) {
        label = l.get('chat_date_today');
      } else if (msgDate == today.subtract(const Duration(days: 1))) {
        label = l.get('chat_date_yesterday');
      } else if (dt.year == now.year) {
        label = '${dt.month}/${dt.day}';
      } else {
        label = '${dt.year}/${dt.month}/${dt.day}';
      }
    } catch (e) {
      label = dateStr;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppTheme.dividerColor, thickness: 0.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textHint)),
          ),
          Expanded(child: Divider(color: AppTheme.dividerColor, thickness: 0.5)),
        ],
      ),
    );
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
