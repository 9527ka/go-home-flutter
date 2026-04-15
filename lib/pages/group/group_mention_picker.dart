import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/group_member.dart';
import '../../widgets/avatar_widget.dart';

/// 群内 @ 成员选择器
///
/// 调用：
///   final picked = await showModalBottomSheet<GroupMemberModel>(
///     context: ctx,
///     isScrollControlled: true,
///     builder: (_) => GroupMentionPicker(members: members, excludeUserId: myUid),
///   );
class GroupMentionPicker extends StatefulWidget {
  final List<GroupMemberModel> members;
  final int? excludeUserId;

  const GroupMentionPicker({
    super.key,
    required this.members,
    this.excludeUserId,
  });

  @override
  State<GroupMentionPicker> createState() => _GroupMentionPickerState();
}

class _GroupMentionPickerState extends State<GroupMentionPicker> {
  final _ctrl = TextEditingController();
  String _keyword = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<GroupMemberModel> get _filtered {
    final base = widget.members
        .where((m) => m.userId != widget.excludeUserId)
        .toList();
    if (_keyword.isEmpty) return base;
    final k = _keyword.toLowerCase();
    return base.where((m) {
      return m.userNickname.toLowerCase().contains(k) ||
          m.alias.toLowerCase().contains(k) ||
          m.userCode.toLowerCase().contains(k);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final mediaQuery = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) {
          final list = _filtered;
          return Container(
            decoration: const BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    l.get('group_mention_pick'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _ctrl,
                    decoration: InputDecoration(
                      hintText: l.get('group_mention_search'),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (v) => setState(() => _keyword = v.trim()),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: list.isEmpty
                      ? Center(
                          child: Text(
                            l.get('search_no_results'),
                            style: const TextStyle(color: AppTheme.textHint),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: list.length,
                          itemBuilder: (_, i) {
                            final m = list[i];
                            final displayName = m.alias.isNotEmpty ? m.alias : m.userNickname;
                            return ListTile(
                              leading: AvatarWidget(
                                avatarPath: m.userAvatar,
                                name: m.userNickname,
                                size: 36,
                              ),
                              title: Text(displayName),
                              subtitle: m.alias.isNotEmpty
                                  ? Text(m.userNickname, style: const TextStyle(fontSize: 12, color: AppTheme.textHint))
                                  : null,
                              onTap: () => Navigator.pop(context, m),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
