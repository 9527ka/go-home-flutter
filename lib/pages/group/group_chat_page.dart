import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/chat_message.dart';
import '../../models/group.dart';
import '../../providers/auth_provider.dart';
import '../../services/group_service.dart';

class GroupChatPage extends StatefulWidget {
  final int groupId;

  const GroupChatPage({super.key, required this.groupId});

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _groupService = GroupService();

  GroupModel? _group;
  List<ChatMessageModel> _messages = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _isSending = false;

  /// System avatar style map
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

  @override
  void initState() {
    super.initState();
    _loadGroupInfo();
    _loadMessages();

    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels <= 50 && !_isLoadingMore && _hasMore) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadGroupInfo() async {
    try {
      final data = await _groupService.getGroupDetail(widget.groupId);
      if (data != null && mounted) {
        setState(() {
          _group = GroupModel.fromJson(data['group'] ?? data);
        });
      }
    } catch (e) {
      debugPrint('[GroupChat] loadGroupInfo error: $e');
    }
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final data = await _groupService.getMessages(
        groupId: widget.groupId,
        limit: 50,
      );
      if (mounted) {
        final list = data['list'] as List? ?? [];
        setState(() {
          _messages = list
              .map((e) =>
                  ChatMessageModel.fromJson(e as Map<String, dynamic>))
              .toList();
          _hasMore = data['has_more'] == true;
        });
        // Scroll to bottom after first load
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

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _messages.isEmpty) return;

    _isLoadingMore = true;
    final prevCount = _messages.length;
    final prevMaxExtent =
        _scrollCtrl.hasClients ? _scrollCtrl.position.maxScrollExtent : 0.0;

    try {
      final firstMsgId = _messages.first.id;
      final data = await _groupService.getMessages(
        groupId: widget.groupId,
        beforeId: firstMsgId,
        limit: 50,
      );
      if (mounted) {
        final list = data['list'] as List? ?? [];
        final olderMessages = list
            .map((e) =>
                ChatMessageModel.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() {
          _messages = [...olderMessages, ..._messages];
          _hasMore = data['has_more'] == true;
        });

        // Retain scroll position
        if (_scrollCtrl.hasClients) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _scrollCtrl.hasClients) {
              final newMaxExtent = _scrollCtrl.position.maxScrollExtent;
              final diff = newMaxExtent - prevMaxExtent;
              if (diff > 0 && _messages.length > prevCount) {
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

  Future<void> _sendMessage() async {
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

    setState(() => _isSending = true);

    try {
      // Create a local message optimistically
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

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });

      // TODO: Send via WebSocket when group chat WebSocket is integrated
      // For now, the message is displayed locally as a placeholder
      // Future integration: ChatProvider.sendGroupMessage(groupId, text)
      debugPrint(
        '[GroupChat] sendMessage placeholder: '
        '{type: group_message, group_id: ${widget.groupId}, content: $text}',
      );
    } catch (e) {
      debugPrint('[GroupChat] sendMessage error: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

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
            icon: const Icon(Icons.info_outline, size: 22),
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
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            // Loading indicator for history
            if (_isLoading && _messages.isNotEmpty)
              const Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),

            // Message list
            Expanded(
              child: _isLoading && _messages.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                      ),
                    )
                  : _messages.isEmpty
                      ? _buildEmpty(l)
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          itemCount: _messages.length,
                          itemBuilder: (ctx, index) {
                            final msg = _messages[index];

                            Widget? dateSeparator;
                            if (index == 0 ||
                                _shouldShowDateSeparator(
                                    _messages, index)) {
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

            // Input bar
            _buildInputBar(l),
          ],
        ),
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

  bool _shouldShowDateSeparator(
      List<ChatMessageModel> messages, int index) {
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
          Expanded(
            child:
                Divider(color: AppTheme.dividerColor, thickness: 0.5),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style:
                  const TextStyle(fontSize: 11, color: AppTheme.textHint),
            ),
          ),
          Expanded(
            child:
                Divider(color: AppTheme.dividerColor, thickness: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel msg, int? currentUserId) {
    final isMe = currentUserId != null && msg.userId == currentUserId;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Nickname + time
          Padding(
            padding: EdgeInsets.only(
              bottom: 2,
              left: isMe ? 2 : 46,
              right: isMe ? 46 : 2,
            ),
            child: Text(
              '${msg.nickname}  ${_formatTime(msg.createdAt)}',
              style:
                  const TextStyle(fontSize: 11, color: AppTheme.textHint),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMe) ...[
                _buildAvatar(msg.avatar, msg.nickname,
                    size: 36, isMe: false),
                const SizedBox(width: 8),
              ],
              Flexible(child: _buildTextBubble(msg, isMe)),
              if (isMe) ...[
                const SizedBox(width: 8),
                _buildAvatar(msg.avatar, msg.nickname,
                    size: 36, isMe: true),
              ],
            ],
          ),
        ],
      ),
    );
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

  Widget _buildInputBar(AppLocalizations l) {
    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
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
          // Text input
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              minLines: 1,
              maxLines: 4,
              maxLength: 500,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: l.get('chat_input_hint'),
                hintStyle: const TextStyle(color: AppTheme.textHint),
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
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
                  borderSide: const BorderSide(
                    color: AppTheme.primaryColor,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Send button
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
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                onPressed: _isSending ? null : _sendMessage,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String avatarUrl, String name,
      {double size = 36, bool isMe = false}) {
    final initial =
        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';

    // System preset avatar
    if (avatarUrl.startsWith('/system/avatars/')) {
      final style = _sysAvatarMap[avatarUrl];
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

    // Network image
    if (avatarUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: Image.network(
          avatarUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _avatarPlaceholder(initial, size, isMe),
        ),
      );
    }

    // Fallback: first letter
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
}
