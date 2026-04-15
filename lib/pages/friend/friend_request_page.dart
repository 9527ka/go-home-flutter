import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/friend_request.dart';
import '../../providers/friend_provider.dart';
import '../../widgets/avatar_widget.dart';

class FriendRequestPage extends StatefulWidget {
  const FriendRequestPage({super.key});

  @override
  State<FriendRequestPage> createState() => _FriendRequestPageState();
}

class _FriendRequestPageState extends State<FriendRequestPage> {
  bool _initialLoading = true;
  final Set<int> _processingIds = {}; // 防重复点击

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await context.read<FriendProvider>().loadRequests();
    if (mounted) {
      setState(() => _initialLoading = false);
    }
  }

  Future<void> _acceptRequest(FriendRequestModel request) async {
    if (_processingIds.contains(request.id)) return;
    setState(() => _processingIds.add(request.id));

    final l = AppLocalizations.of(context)!;
    try {
      final error = await context.read<FriendProvider>().acceptRequest(
            request.id,
            greetingPreview: l.get('friend_accept_greeting'),
          );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error != null ? l.get(error) : l.get('request_accepted')),
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) setState(() => _processingIds.remove(request.id));
    }
  }

  Future<void> _rejectRequest(FriendRequestModel request) async {
    if (_processingIds.contains(request.id)) return;
    setState(() => _processingIds.add(request.id));

    final l = AppLocalizations.of(context)!;
    try {
      final error = await context.read<FriendProvider>().rejectRequest(request.id);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error != null ? l.get(error) : l.get('request_rejected')),
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) setState(() => _processingIds.remove(request.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final friendProvider = context.watch<FriendProvider>();
    final requests = friendProvider.requests;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(l.get('friend_requests')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _initialLoading
          ? const Center(child: CircularProgressIndicator())
          : requests.isEmpty
          ? _buildEmpty(l)
          : RefreshIndicator(
              onRefresh: () => friendProvider.loadRequests(),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: requests.length,
                itemBuilder: (_, index) => _buildRequestItem(requests[index], l),
              ),
            ),
    );
  }

  Widget _buildRequestItem(FriendRequestModel request, AppLocalizations l) {
    // 显示名称：优先 fromNickname，为空时用 ID 兜底
    final displayName = request.fromNickname.isNotEmpty
        ? request.fromNickname
        : 'GH${request.fromId}';

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AvatarWidget(avatarPath: request.fromAvatar, name: displayName, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nickname
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Message (if any)
                  if (request.message.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      request.message,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  // Timestamp
                  Text(
                    _formatTime(context, request.createdAt),
                    style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
                  ),
                  const SizedBox(height: 10),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 34,
                          child: ElevatedButton(
                            onPressed: _processingIds.contains(request.id)
                                ? null
                                : () => _acceptRequest(request),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.successColor,
                              foregroundColor: Colors.white,
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            child: _processingIds.contains(request.id)
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text(l.get('accept')),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 34,
                          child: OutlinedButton(
                            onPressed: _processingIds.contains(request.id)
                                ? null
                                : () => _rejectRequest(request),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textSecondary,
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              side: const BorderSide(color: AppTheme.dividerColor, width: 1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            child: Text(l.get('reject')),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
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
              color: AppTheme.warningColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.mail_outline,
              size: 40,
              color: AppTheme.warningColor.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l.get('no_requests'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l.get('friend_requests'),
            style: const TextStyle(fontSize: 13, color: AppTheme.textHint),
          ),
        ],
      ),
    );
  }

  String _formatTime(BuildContext context, String dateStr) {
    final l = AppLocalizations.of(context)!;
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return l.get('time_just_now');
      if (diff.inMinutes < 60) return l.get('time_minutes_ago').replaceAll('{n}', '${diff.inMinutes}');
      if (diff.inHours < 24) return l.get('time_hours_ago').replaceAll('{n}', '${diff.inHours}');
      if (diff.inDays < 7) return l.get('time_days_ago').replaceAll('{n}', '${diff.inDays}');
      if (diff.inDays < 365) return '${date.month}/${date.day}';
      return '${date.year}/${date.month}/${date.day}';
    } catch (e) {
      return dateStr;
    }
  }
}
