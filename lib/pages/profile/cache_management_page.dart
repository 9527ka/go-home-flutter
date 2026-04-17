import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/conversation.dart';
import '../../pages/chat/private_chat_page.dart';
import '../../pages/group/group_chat_page.dart';
import '../../providers/conversation_provider.dart';
import '../../services/chat_database.dart';
import '../../widgets/avatar_widget.dart';

/// 缓存管理页 — 显示每个会话占用，支持选择清理
class CacheManagementPage extends StatefulWidget {
  const CacheManagementPage({super.key});

  @override
  State<CacheManagementPage> createState() => _CacheManagementPageState();
}

class _CacheManagementPageState extends State<CacheManagementPage> {
  List<ConversationStorageInfo> _stats = [];
  int _totalSize = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final db = ChatDatabase.instance;
    if (!db.isOpen) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final stats = await db.getStorageStats();
    final totalSize = await db.getDatabaseSize();
    if (mounted) {
      setState(() {
        _stats = stats;
        _totalSize = totalSize;
        _isLoading = false;
      });
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  ConversationModel? _findConv(String chatType, int chatId) {
    final convs = context.read<ConversationProvider>().conversations;
    return convs.cast<ConversationModel?>().firstWhere(
      (c) => c!.targetType == chatType && c.targetId == chatId,
      orElse: () => null,
    );
  }

  String _convName(ConversationStorageInfo info, AppLocalizations l) {
    final conv = _findConv(info.chatType, info.chatId);
    if (conv != null) return conv.name;
    return info.chatType == 'private' ? 'ID:${info.chatId}' : '${l.get('groups')} ${info.chatId}';
  }

  Future<void> _clearConversation(ConversationStorageInfo info, AppLocalizations l) async {
    final name = _convName(info, l);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.get('cache_clear_confirm_title')),
        content: Text('${l.get('cache_clear_confirm')}\n\n$name - ${info.messageCount} ${l.get('cache_messages_unit')}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.get('cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerColor, foregroundColor: Colors.white),
            child: Text(l.get('confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ChatDatabase.instance.clearConversation(info.chatType, info.chatId);
    // 清除进程内缓存
    if (info.chatType == 'private') {
      PrivateChatPage.invalidateCache(info.chatId);
    } else {
      GroupChatPage.invalidateCache(info.chatId);
    }
    _loadStats();
  }

  Future<void> _clearAll(AppLocalizations l) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.get('cache_clear_confirm_title')),
        content: Text(l.get('cache_clear_all_confirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.get('cancel'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerColor, foregroundColor: Colors.white),
            child: Text(l.get('confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ChatDatabase.instance.clearAll();
    PrivateChatPage.invalidateAllCaches();
    GroupChatPage.invalidateAllCaches();
    _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(title: Text(l.get('cache_management'))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 总存储
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.storage_outlined, size: 28, color: AppTheme.primaryColor),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.get('cache_total_size'), style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                            const SizedBox(height: 4),
                            Text(_formatSize(_totalSize), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                          ],
                        ),
                      ),
                      if (_stats.isNotEmpty)
                        OutlinedButton(
                          onPressed: () => _clearAll(l),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.dangerColor,
                            side: const BorderSide(color: AppTheme.dangerColor),
                          ),
                          child: Text(l.get('cache_clear_all')),
                        ),
                    ],
                  ),
                ),

                if (_stats.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  // 会话列表
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Column(
                      children: [
                        for (int i = 0; i < _stats.length; i++) ...[
                          if (i > 0) const Divider(height: 0.5, indent: 68),
                          _buildConvRow(_stats[i], l),
                        ],
                      ],
                    ),
                  ),
                ],

                if (_stats.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Center(
                      child: Text(l.get('no_results'), style: const TextStyle(color: AppTheme.textHint)),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildConvRow(ConversationStorageInfo info, AppLocalizations l) {
    final conv = _findConv(info.chatType, info.chatId);
    final name = _convName(info, l);
    final avatar = conv?.avatar ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          AvatarWidget(avatarPath: avatar, name: name, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  '${info.messageCount} ${l.get('cache_messages_unit')} · ${_formatSize(info.estimatedBytes)}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.textHint),
            onPressed: () => _clearConversation(info, l),
          ),
        ],
      ),
    );
  }
}
