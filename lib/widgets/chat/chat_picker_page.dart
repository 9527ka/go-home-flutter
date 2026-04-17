import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/conversation.dart';
import '../../providers/conversation_provider.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/group_grid_avatar.dart';

/// 微信风格的"选择聊天"页面 — 直接展示最近会话列表
///
/// 返回值 Map:
///   - targetType: 'private' | 'group'
///   - targetId: int
///   - name: String
///   - avatar: String
class ChatPickerPage extends StatefulWidget {
  final String title;

  const ChatPickerPage({super.key, this.title = ''});

  @override
  State<ChatPickerPage> createState() => _ChatPickerPageState();
}

class _ChatPickerPageState extends State<ChatPickerPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConversationProvider>().loadConversationsIfEmpty();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ConversationModel> _filtered(List<ConversationModel> convs) {
    if (_query.isEmpty) return convs;
    return convs.where((c) => c.name.toLowerCase().contains(_query)).toList();
  }

  void _onSelect(ConversationModel conv) {
    Navigator.pop(context, {
      'targetType': conv.targetType,
      'targetId': conv.targetId,
      'name': conv.name,
      'avatar': conv.avatar,
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final convProvider = context.watch<ConversationProvider>();
    final convs = _filtered(convProvider.conversations);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(widget.title.isNotEmpty ? widget.title : l.get('select_chat')),
        leading: IconButton(
          icon: const Icon(Icons.close, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: l.get('search'),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => _searchCtrl.clear(),
                      )
                    : null,
                filled: true,
                fillColor: AppTheme.cardBg,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // 会话列表
          Expanded(
            child: convs.isEmpty
                ? Center(
                    child: Text(l.get('no_results'),
                        style: const TextStyle(color: AppTheme.textHint)),
                  )
                : ListView.builder(
                    itemCount: convs.length,
                    itemBuilder: (ctx, i) {
                      final conv = convs[i];
                      return ListTile(
                        leading: conv.isGroup && conv.memberAvatars.isNotEmpty
                            ? GroupGridAvatar(
                                avatars: conv.memberAvatars,
                                names: conv.memberNames,
                                size: 44,
                              )
                            : AvatarWidget(
                                avatarPath: conv.avatar,
                                name: conv.name,
                                size: 44,
                              ),
                        title: Text(conv.name, style: const TextStyle(fontSize: 15)),
                        onTap: () => _onSelect(conv),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
