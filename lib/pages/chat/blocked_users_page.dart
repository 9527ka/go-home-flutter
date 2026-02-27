import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/chat_provider.dart';

/// 屏蔽用户管理页面 — 查看已屏蔽用户并可取消屏蔽
class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  @override
  void initState() {
    super.initState();
    // 确保屏蔽列表已加载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadBlockedUsers();
    });
  }

  void _confirmUnblock(int userId) {
    final l = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l.get('unblock_user')),
        content: Text(l.get('unblock_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.get('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _unblockUser(userId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
              foregroundColor: Colors.white,
            ),
            child: Text(l.get('confirm')),
          ),
        ],
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final chatProvider = context.watch<ChatProvider>();
    final blockedIds = chatProvider.blockedUserIds.toList();

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(l.get('blocked_users')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: blockedIds.isEmpty
          ? _buildEmpty(l)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: blockedIds.length,
              itemBuilder: (_, index) => _buildBlockedUserItem(blockedIds[index], l),
            ),
    );
  }

  Widget _buildBlockedUserItem(int userId, AppLocalizations l) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // 头像占位
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.dangerColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.block_rounded, size: 22, color: AppTheme.dangerColor),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GH$userId',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ID: $userId',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
                  ),
                ],
              ),
            ),
            // 取消屏蔽按钮
            SizedBox(
              height: 34,
              child: OutlinedButton(
                onPressed: () => _confirmUnblock(userId),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.successColor,
                  side: const BorderSide(color: AppTheme.successColor, width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
                child: Text(l.get('unblock_user')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(AppLocalizations l) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.successColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.check_circle_outline,
              size: 40,
              color: AppTheme.successColor.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l.get('no_blocked_users'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l.get('no_blocked_users_hint'),
            style: const TextStyle(fontSize: 13, color: AppTheme.textHint),
          ),
        ],
      ),
    );
  }
}
