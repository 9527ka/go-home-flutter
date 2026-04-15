import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/chat_message.dart';
import '../../services/group_service.dart';
import '../../widgets/avatar_widget.dart';

/// 群聊消息搜索页
///
/// 行为：
/// 1. 立即在 `localMessages`（已加载消息）中过滤显示
/// 2. 输入有变化后 350ms 防抖，再去后端搜索更早的消息
/// 3. 后端返回的消息合并到本地结果（按 id 去重）
class GroupMessageSearchPage extends StatefulWidget {
  final int groupId;
  final List<ChatMessageModel> localMessages;

  const GroupMessageSearchPage({
    super.key,
    required this.groupId,
    required this.localMessages,
  });

  @override
  State<GroupMessageSearchPage> createState() => _GroupMessageSearchPageState();
}

class _GroupMessageSearchPageState extends State<GroupMessageSearchPage> {
  final _ctrl = TextEditingController();
  final _service = GroupService();
  Timer? _debounce;

  String _keyword = '';
  bool _serverLoading = false;
  List<ChatMessageModel> _serverResults = [];

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String v) {
    final keyword = v.trim();
    setState(() => _keyword = keyword);
    _debounce?.cancel();
    if (keyword.isEmpty) {
      setState(() => _serverResults = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _searchServer(keyword));
  }

  Future<void> _searchServer(String keyword) async {
    if (keyword.isEmpty) return;
    setState(() => _serverLoading = true);
    try {
      final data = await _service.getMessages(
        groupId: widget.groupId,
        keyword: keyword,
        limit: 50,
      );
      if (!mounted || _keyword != keyword) return;
      final list = (data['list'] as List? ?? [])
          .map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() => _serverResults = list);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _serverLoading = false);
    }
  }

  /// 合并本地结果 + 服务端结果，按 id 去重，按时间升序
  List<ChatMessageModel> get _mergedResults {
    if (_keyword.isEmpty) return [];
    final keyLower = _keyword.toLowerCase();
    final localMatches = widget.localMessages.where((m) {
      return m.msgType == ChatMsgType.text &&
          m.content.toLowerCase().contains(keyLower);
    });

    final byId = <int, ChatMessageModel>{};
    final noId = <ChatMessageModel>[];
    for (final m in [...localMatches, ..._serverResults]) {
      if (m.id != null && m.id! > 0) {
        byId[m.id!] = m;
      } else {
        noId.add(m);
      }
    }
    final merged = [...byId.values, ...noId];
    merged.sort((a, b) {
      final aId = a.id ?? 0;
      final bId = b.id ?? 0;
      return aId.compareTo(bId);
    });
    return merged;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final results = _mergedResults;
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l.get('search_messages_hint'),
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
        ),
        actions: [
          if (_keyword.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () {
                _ctrl.clear();
                _onChanged('');
              },
            ),
        ],
      ),
      body: _keyword.isEmpty
          ? _buildEmpty(l, l.get('search_messages_hint'))
          : Column(
              children: [
                if (_serverLoading)
                  const LinearProgressIndicator(
                    minHeight: 2,
                    color: AppTheme.primaryColor,
                  ),
                Expanded(
                  child: results.isEmpty && !_serverLoading
                      ? _buildEmpty(l, l.get('search_no_results'))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: results.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 64),
                          itemBuilder: (_, i) => _buildResult(results[i]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildResult(ChatMessageModel msg) {
    return ListTile(
      leading: AvatarWidget(avatarPath: msg.avatar, name: msg.nickname, size: 36),
      title: Text(msg.nickname, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: _buildHighlightedContent(msg.content),
      trailing: Text(
        _formatTime(msg.createdAt),
        style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
      ),
    );
  }

  Widget _buildHighlightedContent(String content) {
    if (_keyword.isEmpty) {
      return Text(content, maxLines: 2, overflow: TextOverflow.ellipsis);
    }
    final keyLower = _keyword.toLowerCase();
    final lower = content.toLowerCase();
    final idx = lower.indexOf(keyLower);
    if (idx < 0) {
      return Text(content, maxLines: 2, overflow: TextOverflow.ellipsis);
    }
    // 截取关键词附近的上下文
    final start = (idx - 20).clamp(0, content.length);
    final endIdx = (idx + _keyword.length + 20).clamp(0, content.length);
    final prefix = start > 0 ? '…' : '';
    final suffix = endIdx < content.length ? '…' : '';
    final before = content.substring(start, idx);
    final hit = content.substring(idx, idx + _keyword.length);
    final after = content.substring(idx + _keyword.length, endIdx);

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        children: [
          TextSpan(text: '$prefix$before'),
          TextSpan(
            text: hit,
            style: const TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: '$after$suffix'),
        ],
      ),
    );
  }

  Widget _buildEmpty(AppLocalizations l, String text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search, size: 48, color: AppTheme.textHint),
          const SizedBox(height: 12),
          Text(text, style: const TextStyle(fontSize: 14, color: AppTheme.textHint)),
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
      return '${dt.month}/${dt.day}';
    } catch (_) {
      return '';
    }
  }
}
