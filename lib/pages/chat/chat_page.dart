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
import '../friend/user_profile_page.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _chatService = ChatService();
  final _imagePicker = ImagePicker();
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();

  bool _needsAutoScroll = true;
  bool _isLoadingMore = false;
  bool _showEmojiPicker = false;
  bool _showMediaPanel = false;
  bool _isUploading = false;
  bool _hasInputText = false; // 输入框是否有文字（控制发送按钮显隐）

  // 语音模式 & 录音状态
  bool _voiceMode = false; // 是否处于语音输入模式（切换按钮）
  bool _isRecording = false; // 是否正在录音（按住中）
  bool _cancellingVoice = false; // 手指上滑到取消区域
  int _recordDuration = 0;
  Timer? _recordTimer;
  Timer? _amplitudeTimer; // 振幅采集定时器
  List<double> _amplitudes = []; // 声波振幅历史（用于绘制波形）
  double _currentAmplitude = 0; // 当前振幅 0~1
  OverlayEntry? _recordOverlay; // 录音浮层

  // 语音播放
  String? _playingVoiceUrl; // 当前正在播放的语音 URL

  // 语音上传占位
  int? _uploadingVoiceDuration; // 非空表示正在上传语音，值为时长

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = context.read<ChatProvider>();
      chatProvider.onPageEnter();
      chatProvider.loadHistory().then((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom(animate: false);
        });
      });
      chatProvider.addListener(_onChatUpdate);
    });

    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels <= 50 && !_isLoadingMore) {
        _loadMoreWithScrollRetention();
      }
      if (_scrollCtrl.hasClients) {
        final pos = _scrollCtrl.position;
        _needsAutoScroll = pos.maxScrollExtent - pos.pixels < 150;
      }
    });
  }

  Future<void> _loadMoreWithScrollRetention() async {
    final provider = context.read<ChatProvider>();
    if (provider.isLoading || !provider.hasMore || provider.messages.isEmpty) {
      return;
    }

    _isLoadingMore = true;
    final prevCount = provider.messages.length;
    final prevMaxExtent =
        _scrollCtrl.hasClients ? _scrollCtrl.position.maxScrollExtent : 0.0;

    await provider.loadMore();

    if (!mounted) {
      _isLoadingMore = false;
      return;
    }

    if (_scrollCtrl.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollCtrl.hasClients) {
          final newMaxExtent = _scrollCtrl.position.maxScrollExtent;
          final diff = newMaxExtent - prevMaxExtent;
          if (diff > 0 && provider.messages.length > prevCount) {
            _scrollCtrl.jumpTo(_scrollCtrl.position.pixels + diff);
          }
        }
        _isLoadingMore = false;
      });
    } else {
      _isLoadingMore = false;
    }
  }

  void _onChatUpdate() {
    if (_needsAutoScroll && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToBottom();
      });
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

  bool _checkLogin() {
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
      return false;
    }
    return true;
  }

  void _send() {
    if (!_checkLogin()) return;

    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    context.read<ChatProvider>().sendMessage(text);
    _msgCtrl.clear();
    _needsAutoScroll = true;
  }

  // ===== 表情 =====

  void _toggleEmojiPicker() {
    if (_showEmojiPicker) {
      setState(() => _showEmojiPicker = false);
    } else {
      FocusScope.of(context).unfocus();
      setState(() {
        _showEmojiPicker = true;
        _showMediaPanel = false;
      });
    }
  }

  void _onEmojiSelected(Category? category, Emoji emoji) {
    final text = _msgCtrl.text;
    final selection = _msgCtrl.selection;
    final newText = text.replaceRange(
      selection.start < 0 ? text.length : selection.start,
      selection.end < 0 ? text.length : selection.end,
      emoji.emoji,
    );
    final offset = (selection.start < 0 ? text.length : selection.start) +
        emoji.emoji.length;
    _msgCtrl.text = newText;
    _msgCtrl.selection = TextSelection.collapsed(offset: offset);
  }

  // ===== 多媒体面板 =====

  void _toggleMediaPanel() {
    if (_showMediaPanel) {
      setState(() => _showMediaPanel = false);
    } else {
      FocusScope.of(context).unfocus();
      setState(() {
        _showMediaPanel = true;
        _showEmojiPicker = false;
      });
    }
  }

  // ===== 图片发送 =====

  Future<void> _pickAndSendImage(ImageSource source) async {
    if (!_checkLogin()) return;

    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() => _isUploading = true);
    try {
      final result = await _chatService.uploadImage(picked);
      if (result != null && mounted) {
        context.read<ChatProvider>().sendMediaMessage(
              msgType: 'image',
              mediaUrl: result['url'] ?? '',
              thumbUrl: result['thumb_url'] ?? '',
            );
        _needsAutoScroll = true;
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
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ===== 视频发送 =====

  Future<void> _pickAndSendVideo() async {
    if (!_checkLogin()) return;

    final picked = await _imagePicker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 3),
    );
    if (picked == null) return;

    setState(() => _isUploading = true);
    try {
      final result = await _chatService.uploadVideo(picked);
      if (result != null && mounted) {
        context.read<ChatProvider>().sendMediaMessage(
              msgType: 'video',
              mediaUrl: result['url'] ?? '',
            );
        _needsAutoScroll = true;
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
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ===== 语音模式切换 =====

  void _toggleVoiceMode() {
    if (!_checkLogin()) return;
    if (kIsWeb) {
      Fluttertoast.showToast(
        msg: AppLocalizations.of(context)!.get('voice_not_supported_web'),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _voiceMode = !_voiceMode;
      _showEmojiPicker = false;
      _showMediaPanel = false;
    });
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
        context.read<ChatProvider>().sendMediaMessage(
          msgType: 'voice',
          mediaUrl: result['url'] ?? '',
          mediaInfo: {'duration': duration},
        );
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
    final l = AppLocalizations.of(context)!;
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.center,
          child: Container(
            width: 200,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 麦克风图标 / 取消图标
                Icon(
                  _cancellingVoice ? Icons.close : Icons.mic,
                  size: 36,
                  color: _cancellingVoice ? AppTheme.dangerColor : Colors.white,
                ),
                const SizedBox(height: 12),

                // 声波动画
                SizedBox(
                  height: 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(20, (i) {
                      // 从振幅列表右对齐取值，不足的部分显示最小高度
                      final offset = _amplitudes.length - 20 + i;
                      final amp = offset >= 0 ? _amplitudes[offset] : 0.05;
                      final barHeight = (4 + amp * 36).clamp(4.0, 40.0);
                      return Container(
                        width: 3,
                        height: barHeight,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          color: _cancellingVoice
                              ? AppTheme.dangerColor.withOpacity(0.7)
                              : Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 12),

                // 计时
                Text(
                  '${(_recordDuration ~/ 60).toString().padLeft(2, '0')}:${(_recordDuration % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 10),

                // 提示文字
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _cancellingVoice
                        ? AppTheme.dangerColor
                        : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _cancellingVoice
                        ? l.get('voice_release_cancel')
                        : l.get('voice_slide_cancel'),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      decoration: TextDecoration.none,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _removeRecordOverlay();
    final chatProvider = context.read<ChatProvider>();
    chatProvider.removeListener(_onChatUpdate);
    chatProvider.onPageLeave();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _recordTimer?.cancel();
    _amplitudeTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final chatProvider = context.watch<ChatProvider>();

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.get('chat_room')),
            if (chatProvider.onlineCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppTheme.successColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${chatProvider.onlineCount} ${l.get('online')}',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.successColor),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        // HIDDEN_FEATURE: 聊天室右上角 - 原有"会话列表"入口按钮，恢复时替换为原 actions 代码
        // 原代码: actions: [ IconButton(icon: Icon(Icons.people_outline, size: 22), onPressed: () => Navigator.pushNamed(context, AppRoutes.conversations), tooltip: l.get('conversations')) ]
        actions: const [],
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
            _buildConnectionBanner(chatProvider, l),

            if (chatProvider.isLoading && chatProvider.messages.isNotEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.primaryColor),
                ),
              ),

            // 上传中提示
            if (_isUploading)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                color: AppTheme.primaryColor.withOpacity(0.1),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.primaryColor),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l.get('chat_uploading'),
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.primaryColor),
                    ),
                  ],
                ),
              ),

            // 消息列表
            Expanded(
              child: chatProvider.messages.isEmpty &&
                      !chatProvider.isLoading &&
                      _uploadingVoiceDuration == null
                  ? _buildEmpty(l)
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      itemCount: chatProvider.messages.length +
                          (_uploadingVoiceDuration != null ? 1 : 0),
                      itemBuilder: (ctx, index) {
                        // 末尾额外项：语音上传占位
                        if (index >= chatProvider.messages.length) {
                          return _buildUploadingVoiceBubble();
                        }

                        final currentUserId =
                            context.read<AuthProvider>().user?.id;
                        final msg = chatProvider.messages[index];

                        Widget? dateSeparator;
                        if (index == 0 ||
                            _shouldShowDateSeparator(
                                chatProvider.messages, index)) {
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

            // 输入栏（语音模式时内含「按住说话」按钮）
            _buildInputBar(l, chatProvider),

            // 表情面板
            if (_showEmojiPicker && !_voiceMode) _buildEmojiPicker(),

            // 多媒体面板
            if (_showMediaPanel && !_voiceMode) _buildMediaPanel(l),
          ],
        ),
      ),
    );
  }

  // ===== 表情选择器 =====

  Widget _buildEmojiPicker() {
    return SizedBox(
      height: 260,
      child: EmojiPicker(
        onEmojiSelected: _onEmojiSelected,
        config: Config(
          columns: 8,
          emojiSizeMax:
              28 * (defaultTargetPlatform == TargetPlatform.iOS ? 1.3 : 1.0),
          initCategory: Category.SMILEYS,
          indicatorColor: AppTheme.primaryColor,
          iconColorSelected: AppTheme.primaryColor,
          backspaceColor: AppTheme.primaryColor,
        ),
      ),
    );
  }

  // ===== 多媒体面板 =====

  Widget _buildMediaPanel(AppLocalizations l) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        border: Border(
          top: BorderSide(color: AppTheme.dividerColor, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _mediaButton(
            icon: Icons.camera_alt_rounded,
            label: l.get('take_photo'),
            onTap: () => _pickAndSendImage(ImageSource.camera),
          ),
          _mediaButton(
            icon: Icons.photo_library_rounded,
            label: l.get('chat_album'),
            onTap: () => _pickAndSendImage(ImageSource.gallery),
          ),
          _mediaButton(
            icon: Icons.videocam_rounded,
            label: l.get('chat_video'),
            onTap: _pickAndSendVideo,
          ),
        ],
      ),
    );
  }

  Widget _mediaButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
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
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 26, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
          ),
        ],
      ),
    );
  }

  // ===== 消息气泡 =====

  bool _shouldShowDateSeparator(List<ChatMessageModel> messages, int index) {
    if (index == 0) return true;
    try {
      final current = DateTime.parse(messages[index].createdAt);
      final previous = DateTime.parse(messages[index - 1].createdAt);
      return current.year != previous.year ||
          current.month != previous.month ||
          current.day != previous.day;
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

      if (msgDate == today) {
        label = AppLocalizations.of(context)!.get('chat_date_today');
      } else if (msgDate == today.subtract(const Duration(days: 1))) {
        label = AppLocalizations.of(context)!.get('chat_date_yesterday');
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
          Expanded(
              child: Divider(color: AppTheme.dividerColor, thickness: 0.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
            ),
          ),
          Expanded(
              child: Divider(color: AppTheme.dividerColor, thickness: 0.5)),
        ],
      ),
    );
  }

  Widget _buildConnectionBanner(ChatProvider provider, AppLocalizations l) {
    switch (provider.connectionState) {
      case WsConnectionState.connecting:
        return _statusBanner(
          color: AppTheme.warningColor,
          icon: Icons.wifi,
          text: l.get('chat_connecting'),
          showProgress: true,
        );
      case WsConnectionState.reconnecting:
        return _statusBanner(
          color: AppTheme.warningColor,
          icon: Icons.sync,
          text:
              '${l.get('chat_reconnecting')} (${provider.reconnectAttempts}/20)',
          showProgress: true,
        );
      case WsConnectionState.disconnected:
        if (provider.messages.isNotEmpty || provider.reconnectAttempts > 0) {
          return _statusBanner(
            color: AppTheme.dangerColor,
            icon: Icons.wifi_off,
            text: l.get('chat_disconnected'),
            action: TextButton(
              onPressed: () => provider.manualReconnect(),
              child: Text(
                l.get('chat_retry'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      case WsConnectionState.connected:
      case WsConnectionState.authenticated:
        return const SizedBox.shrink();
    }
  }

  Widget _statusBanner({
    required Color color,
    required IconData icon,
    required String text,
    bool showProgress = false,
    Widget? action,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: color.withOpacity(0.9),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          if (showProgress) ...[
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w500),
            ),
          ),
          if (action != null) action,
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
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 30,
              color: AppTheme.primaryColor.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l.get('chat_empty'),
            style: const TextStyle(fontSize: 14, color: AppTheme.textHint),
          ),
        ],
      ),
    );
  }

  /// 系统头像样式映射
  static const _sysAvatarMap = <String, List<dynamic>>{
    '/system/avatars/avatar_1.svg': [Color(0xFF4A90D9), Icons.person],
    '/system/avatars/avatar_2.svg': [Color(0xFF5BA0E8), Icons.person_outline],
    '/system/avatars/avatar_3.svg': [Color(0xFF34A853), Icons.face],
    '/system/avatars/avatar_4.svg': [
      Color(0xFF8B5CF6),
      Icons.sentiment_satisfied_alt
    ],
    '/system/avatars/avatar_5.svg': [Color(0xFFF97316), Icons.emoji_people],
    '/system/avatars/avatar_6.svg': [Color(0xFFEC4899), Icons.face_3],
    '/system/avatars/avatar_7.svg': [Color(0xFFF43F5E), Icons.face_4],
    '/system/avatars/avatar_8.svg': [Color(0xFFA855F7), Icons.face_2],
    '/system/avatars/avatar_9.svg': [Color(0xFF06B6D4), Icons.face_5],
    '/system/avatars/avatar_10.svg': [Color(0xFFEAB308), Icons.face_6],
  };

  Widget _buildAvatar(ChatMessageModel msg,
      {double size = 36, bool isMe = false}) {
    final initial = msg.nickname.isNotEmpty
        ? msg.nickname.substring(0, 1).toUpperCase()
        : '?';

    // 系统预设头像
    if (msg.avatar.startsWith('/system/avatars/')) {
      final style = _sysAvatarMap[msg.avatar];
      if (style != null) {
        final color = style[0] as Color;
        final icon = style[1] as IconData;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(size * 0.28),
          ),
          child: Center(
            child: Icon(icon, size: size * 0.55, color: color),
          ),
        );
      }
    }

    if (msg.avatar.isNotEmpty) {
      final avatarUrl = msg.avatar;

      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: Image.network(
          avatarUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _avatarPlaceholder(initial, size, isMe),
        ),
      );
    }

    return _avatarPlaceholder(initial, size, isMe);
  }

  Widget _avatarPlaceholder(String initial, double size, bool isMe) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isMe ? AppTheme.primaryColor : AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.39,
            fontWeight: FontWeight.w600,
            color: isMe ? Colors.white : AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel msg, int? currentUserId) {
    final isMe = currentUserId != null && msg.userId == currentUserId;
    final chatProvider = context.read<ChatProvider>();
    final isBlocked = chatProvider.isUserBlocked(msg.userId);

    // 被屏蔽用户的消息显示为占位
    if (isBlocked && !isMe) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onLongPress: isMe
          ? null
          : () => _showMessageActions(msg),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(
                bottom: 2,
                left: isMe ? 2 : 46,
                right: isMe ? 46 : 2,
              ),
              child: Text(
                '${msg.nickname}  ${_formatTime(msg.createdAt)}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment:
                  isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                if (!isMe) ...[
                  GestureDetector(
                    onTap: () => _showUserProfile(msg),
                    child: _buildAvatar(msg, isMe: false),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(child: _buildBubbleContent(msg, isMe)),
                if (isMe) ...[
                  const SizedBox(width: 8),
                  _buildAvatar(msg, isMe: true),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 长按消息弹出操作菜单（举报 / 屏蔽）
  void _showMessageActions(ChatMessageModel msg) {
    final l = AppLocalizations.of(context)!;
    final chatProvider = context.read<ChatProvider>();
    final isBlocked = chatProvider.isUserBlocked(msg.userId);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 举报消息
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: AppTheme.warningColor),
                title: Text(l.get('chat_report')),
                onTap: () {
                  Navigator.pop(ctx);
                  _reportMessage(msg);
                },
              ),
              // 屏蔽/取消屏蔽用户
              ListTile(
                leading: Icon(
                  isBlocked ? Icons.visibility_rounded : Icons.block_rounded,
                  color: isBlocked ? AppTheme.successColor : AppTheme.dangerColor,
                ),
                title: Text(isBlocked ? l.get('unblock_user') : l.get('block_user')),
                onTap: () {
                  Navigator.pop(ctx);
                  if (isBlocked) {
                    _unblockUser(msg.userId);
                  } else {
                    _confirmBlockUser(msg.userId);
                  }
                },
              ),
              // 取消
              ListTile(
                leading: const Icon(Icons.close, color: AppTheme.textHint),
                title: Text(l.get('cancel')),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 举报消息
  void _reportMessage(ChatMessageModel msg) {
    showDialog(
      context: context,
      builder: (_) => _ChatReportDialog(
        messageId: msg.id ?? 0,
        userId: msg.userId,
        chatService: _chatService,
      ),
    );
  }

  /// 确认屏蔽用户
  void _confirmBlockUser(int userId) {
    final l = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.get('block_user')),
        content: Text(l.get('block_user_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.get('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ChatProvider>().blockUser(userId);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l.get('block_success')),
                  backgroundColor: AppTheme.successColor,
                  action: SnackBarAction(
                    label: l.get('blocked_users'),
                    textColor: Colors.white,
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.blockedUsers);
                    },
                  ),
                ),
              );
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

  /// 取消屏蔽用户
  void _unblockUser(int userId) {
    final l = AppLocalizations.of(context)!;
    context.read<ChatProvider>().unblockUser(userId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.get('unblock_success')),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  /// 点击头像查看用户资料
  void _showUserProfile(ChatMessageModel msg) {
    UserProfilePage.show(
      context,
      userId: msg.userId,
      nickname: msg.nickname,
      avatar: msg.avatar,
      userCode: msg.userCode,
    );
  }

  /// 根据消息类型构建不同的气泡内容
  Widget _buildBubbleContent(ChatMessageModel msg, bool isMe) {
    switch (msg.msgType) {
      case ChatMsgType.image:
        return _buildImageBubble(msg, isMe);
      case ChatMsgType.video:
        return _buildVideoBubble(msg, isMe);
      case ChatMsgType.voice:
        return _buildVoiceBubble(msg, isMe);
      case ChatMsgType.text:
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
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        msg.content,
        style: TextStyle(
          fontSize: 14,
          color: isMe ? Colors.white : AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildImageBubble(ChatMessageModel msg, bool isMe) {
    final imageUrl = msg.thumbUrl.isNotEmpty ? msg.thumbUrl : msg.mediaUrl;
    final fullUrl = imageUrl;
    final fullImageUrl = msg.mediaUrl;

    return GestureDetector(
      onTap: () => _showFullImage(fullImageUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isMe ? 14 : 4),
          topRight: Radius.circular(isMe ? 4 : 14),
          bottomLeft: const Radius.circular(14),
          bottomRight: const Radius.circular(14),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200),
          child: CachedNetworkImage(
            imageUrl: fullUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              width: 150,
              height: 150,
              color: AppTheme.scaffoldBg,
              child: const Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.primaryColor),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              width: 150,
              height: 100,
              color: AppTheme.scaffoldBg,
              child: const Icon(Icons.broken_image,
                  color: AppTheme.textHint, size: 40),
            ),
          ),
        ),
      ),
    );
  }

  void _showFullImage(String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          extendBodyBehindAppBar: true,
          body: Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (_, __) =>
                    const CircularProgressIndicator(color: Colors.white),
                errorWidget: (_, __, ___) => const Icon(Icons.broken_image,
                    color: Colors.white54, size: 60),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoBubble(ChatMessageModel msg, bool isMe) {
    final thumbUrl = msg.thumbUrl;

    return GestureDetector(
      onTap: () {
        _playVideo(msg.mediaUrl);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isMe ? 14 : 4),
          topRight: Radius.circular(isMe ? 4 : 14),
          bottomLeft: const Radius.circular(14),
          bottomRight: const Radius.circular(14),
        ),
        child: Container(
          width: 200,
          height: 150,
          color: Colors.black87,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (thumbUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: thumbUrl,
                  fit: BoxFit.cover,
                  width: 200,
                  height: 150,
                ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _playVideo(String url) {
    // 简单方案：使用系统播放器打开视频
    // 如需内嵌播放可在此添加 video_player 页面
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _VideoPlayerPage(url: url),
      ),
    );
  }

  Widget _buildVoiceBubble(ChatMessageModel msg, bool isMe) {
    final duration = msg.voiceDuration;
    // 根据时长计算气泡宽度（最小 80, 最大 200）
    final width = (80 + (duration * 3.0)).clamp(80.0, 200.0);
    final voiceUrl = msg.mediaUrl;
    final isPlaying = _playingVoiceUrl == voiceUrl;

    return GestureDetector(
      onTap: () => _playVoice(voiceUrl),
      child: Container(
        width: width,
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
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 播放中显示暂停图标，否则显示声波图标
            Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 20,
              color: isMe ? Colors.white : AppTheme.primaryColor,
            ),
            const SizedBox(width: 4),
            // 简易声波条
            if (isPlaying) ...[
              _buildMiniWave(isMe),
              const SizedBox(width: 4),
            ],
            Text(
              '${duration}"',
              style: TextStyle(
                fontSize: 14,
                color: isMe ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 语音上传中的占位气泡（显示在列表末尾）
  Widget _buildUploadingVoiceBubble() {
    final duration = _uploadingVoiceDuration ?? 0;
    final width = (80 + (duration * 3.0)).clamp(80.0, 200.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              width: width,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.6),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${duration}"',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 占位头像区域（与正常消息对齐）
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  /// 语音气泡内的播放声波动画
  Widget _buildMiniWave(bool isMe) {
    return _VoicePlayingWave(
      color: isMe ? Colors.white.withOpacity(0.9) : AppTheme.primaryColor,
      barCount: 4,
    );
  }

  Future<void> _playVoice(String url) async {
    // 如果点击正在播放的语音，则停止
    if (_playingVoiceUrl == url && _audioPlayer.playing) {
      await _audioPlayer.stop();
      setState(() => _playingVoiceUrl = null);
      return;
    }

    try {
      setState(() => _playingVoiceUrl = url);
      await _audioPlayer.setUrl(url);
      _audioPlayer.play();

      // 播放结束后重置状态
      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (mounted) setState(() => _playingVoiceUrl = null);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _playingVoiceUrl = null);
        Fluttertoast.showToast(
            msg: AppLocalizations.of(context)!.get('upload_failed'));
      }
    }
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

  // ===== 输入栏 =====

  Widget _buildInputBar(AppLocalizations l, ChatProvider provider) {
    final isDisconnected =
        provider.connectionState == WsConnectionState.disconnected ||
            provider.connectionState == WsConnectionState.reconnecting;

    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: (_showEmojiPicker || _showMediaPanel)
            ? 8
            : MediaQuery.of(context).padding.bottom + 8,
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
          // 语音/键盘 模式切换按钮
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: IconButton(
              icon: Icon(
                _voiceMode ? Icons.keyboard_rounded : Icons.mic_rounded,
                color:
                    _voiceMode ? AppTheme.primaryColor : AppTheme.textSecondary,
                size: 24,
              ),
              onPressed: isDisconnected ? null : _toggleVoiceMode,
            ),
          ),

          // 语音模式：按住说话按钮 / 文字模式：输入框
          Expanded(
            child: _voiceMode
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _buildHoldToTalkButton(l, isDisconnected),
                  )
                : TextField(
                    controller: _msgCtrl,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 500,
                    textInputAction: TextInputAction.newline,
                    onTap: () {
                      setState(() {
                        _showEmojiPicker = false;
                        _showMediaPanel = false;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: isDisconnected
                          ? l.get('chat_disconnected_hint')
                          : l.get('chat_input_hint'),
                      hintStyle: const TextStyle(color: AppTheme.textHint),
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      filled: true,
                      fillColor: AppTheme.scaffoldBg,
                      // 表情按钮放到输入框内右侧
                      suffixIcon: GestureDetector(
                        onTap: isDisconnected ? null : _toggleEmojiPicker,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            _showEmojiPicker
                                ? Icons.keyboard_rounded
                                : Icons.emoji_emotions_outlined,
                            color: _showEmojiPicker
                                ? AppTheme.primaryColor
                                : AppTheme.textHint,
                            size: 22,
                          ),
                        ),
                      ),
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
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
                        borderSide: const BorderSide(
                            color: AppTheme.primaryColor, width: 1.5),
                      ),
                    ),
                  ),
          ),

          const SizedBox(width: 4),

          // + 更多（图片/视频）
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: IconButton(
              icon: Icon(
                Icons.add_circle_outline,
                color: _showMediaPanel
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary,
                size: 24,
              ),
              onPressed: isDisconnected ? null : _toggleMediaPanel,
            ),
          ),

          // 发送按钮
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDisconnected
                      ? [Colors.grey.shade400, Colors.grey.shade500]
                      : const [Color(0xFF5BA0E8), Color(0xFF4A90D9)],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20),
                onPressed: isDisconnected ? null : _send,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 微信风格「按住说话」按钮
  Widget _buildHoldToTalkButton(AppLocalizations l, bool isDisconnected) {
    return GestureDetector(
      onLongPressStart: isDisconnected ? null : (_) => _onVoiceStart(),
      onLongPressMoveUpdate: isDisconnected ? null : _onVoiceMove,
      onLongPressEnd: isDisconnected ? null : (_) => _onVoiceEnd(),
      onLongPressCancel: isDisconnected ? null : _onVoiceCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 44,
        decoration: BoxDecoration(
          color: _isRecording
              ? AppTheme.primaryColor.withOpacity(0.12)
              : AppTheme.scaffoldBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: _isRecording
                ? AppTheme.primaryColor.withOpacity(0.4)
                : Colors.transparent,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          _isRecording ? l.get('voice_recording') : l.get('voice_hold_to_talk'),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color:
                _isRecording ? AppTheme.primaryColor : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ===== 语音播放声波动画 =====

class _VoicePlayingWave extends StatefulWidget {
  final Color color;
  final int barCount;
  const _VoicePlayingWave({required this.color, this.barCount = 4});

  @override
  State<_VoicePlayingWave> createState() => _VoicePlayingWaveState();
}

class _VoicePlayingWaveState extends State<_VoicePlayingWave>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(widget.barCount, (i) {
          // 每根竖条的相位不同，形成波浪效果
          final phase = (i / widget.barCount) * 2 * math.pi;
          final sinVal = math.sin(_ctrl.value * 2 * math.pi + phase);
          final height = 5.0 + (sinVal + 1) / 2 * 11.0; // 5~16
          return Container(
            width: 2.5,
            height: height,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(1.5),
            ),
          );
        }),
      ),
    );
  }
}

// ===== 聊天消息举报弹窗 =====

class _ChatReportDialog extends StatefulWidget {
  final int messageId;
  final int userId;
  final ChatService chatService;

  const _ChatReportDialog({
    required this.messageId,
    required this.userId,
    required this.chatService,
  });

  @override
  State<_ChatReportDialog> createState() => _ChatReportDialogState();
}

class _ChatReportDialogState extends State<_ChatReportDialog> {
  int? _reason;
  final _descCtrl = TextEditingController();
  bool _isSubmitting = false;

  final _reasons = {
    1: '虚假信息',
    2: '广告推销',
    3: '涉及违法',
    4: '骚扰辱骂',
    5: '其他',
  };

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason == null) return;

    setState(() => _isSubmitting = true);

    try {
      final success = await widget.chatService.reportMessage(
        messageId: widget.messageId,
        userId: widget.userId,
        reason: _reason!,
        description: _descCtrl.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context);

      final l = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? l.get('chat_report_success') : '举报失败'),
          backgroundColor: success ? AppTheme.successColor : AppTheme.dangerColor,
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l.get('chat_report')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('请选择举报原因：'),
            const SizedBox(height: 8),
            ..._reasons.entries.map((e) {
              return RadioListTile<int>(
                contentPadding: EdgeInsets.zero,
                title: Text(e.value, style: const TextStyle(fontSize: 14)),
                value: e.key,
                groupValue: _reason,
                onChanged: (v) => setState(() => _reason = v),
              );
            }),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: '补充说明（可选）',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.get('cancel')),
        ),
        ElevatedButton(
          onPressed: _reason == null || _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l.get('submit')),
        ),
      ],
    );
  }
}

// ===== 视频播放页面 =====

class _VideoPlayerPage extends StatefulWidget {
  final String url;
  const _VideoPlayerPage({required this.url});

  @override
  State<_VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<_VideoPlayerPage> {
  late final _controller =
      VideoPlayerController.networkUrl(Uri.parse(widget.url));
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller.initialize().then((_) {
      setState(() => _initialized = true);
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
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: _initialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_controller),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_controller.value.isPlaying) {
                            _controller.pause();
                          } else {
                            _controller.play();
                          }
                        });
                      },
                      child: AnimatedOpacity(
                        opacity: _controller.value.isPlaying ? 0 : 1,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 40),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
