import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../models/notification.dart';
import '../../providers/notification_provider.dart';
import '../../services/notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _notificationService = NotificationService();
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _page = 1;
  bool _hasMore = true;
  int _unreadCount = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    _loadUnread();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _page = 1;
    });
    try {
      final data = await _notificationService.getList(page: 1);
      _notifications = data.list;
      _hasMore = data.hasMore;
      _page = 1;
    } catch (e) {
      // 加载失败
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final data = await _notificationService.getList(page: _page + 1);
      _notifications.addAll(data.list);
      _page = data.page;
      _hasMore = data.hasMore;
    } catch (e) {
      // 加载失败
    }
    if (mounted) setState(() => _isLoadingMore = false);
  }

  Future<void> _loadUnread() async {
    try {
      final count = await _notificationService.getUnreadCount();
      if (mounted) setState(() => _unreadCount = count);
    } catch (e) {
      // ignore
    }
  }

  /// 标记单条已读
  Future<void> _markRead(int index) async {
    final notification = _notifications[index];
    if (!notification.isUnread) return;

    final res = await _notificationService.markRead(id: notification.id);
    if (res['code'] == 0 && mounted) {
      setState(() {
        // 替换为已读版本
        _notifications[index] = NotificationModel(
          id: notification.id,
          userId: notification.userId,
          type: notification.type,
          title: notification.title,
          content: notification.content,
          postId: notification.postId,
          isRead: 1,
          createdAt: notification.createdAt,
        );
        _unreadCount = (_unreadCount - 1).clamp(0, 9999);
      });
      // 同步全局未读数
      context.read<NotificationProvider>().decrementUnread();
    }
  }

  /// 全部标记已读
  Future<void> _markAllRead() async {
    if (_unreadCount == 0) return;

    final res = await _notificationService.markRead();
    if (res['code'] == 0 && mounted) {
      setState(() {
        _notifications = _notifications.map((n) {
          return NotificationModel(
            id: n.id,
            userId: n.userId,
            type: n.type,
            title: n.title,
            content: n.content,
            postId: n.postId,
            isRead: 1,
            createdAt: n.createdAt,
          );
        }).toList();
        _unreadCount = 0;
      });
      // 同步全局未读数
      context.read<NotificationProvider>().clearUnread();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已全部标记为已读'), duration: Duration(seconds: 1)),
        );
      }
    }
  }

  /// 点击通知
  void _onTapNotification(int index) {
    final notification = _notifications[index];

    // 标记为已读
    _markRead(index);

    // 如有关联启事，跳转详情
    if (notification.postId != null && notification.postId! > 0) {
      Navigator.pushNamed(
        context,
        AppRoutes.postDetail,
        arguments: notification.postId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('消息通知'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('全部已读', style: TextStyle(fontSize: 13)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: () async {
                    await _load();
                    await _loadUnread();
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _notifications.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (_, index) {
                      if (index == _notifications.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      return _buildNotificationItem(index);
                    },
                  ),
                ),
    );
  }

  Widget _buildNotificationItem(int index) {
    final notification = _notifications[index];
    final isUnread = notification.isUnread;

    // 通知类型样式
    Color typeColor;
    IconData typeIcon;
    switch (notification.type) {
      case 1: // 线索回复
        typeColor = AppTheme.accentColor;
        typeIcon = Icons.lightbulb_outline;
        break;
      case 2: // 审核通过
        typeColor = AppTheme.successColor;
        typeIcon = Icons.check_circle_outline;
        break;
      case 3: // 审核驳回
        typeColor = AppTheme.dangerColor;
        typeIcon = Icons.cancel_outlined;
        break;
      case 4: // 举报处理
        typeColor = AppTheme.warningColor;
        typeIcon = Icons.flag_outlined;
        break;
      default: // 系统通知
        typeColor = AppTheme.primaryColor;
        typeIcon = Icons.notifications_outlined;
    }

    return GestureDetector(
      onTap: () => _onTapNotification(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isUnread ? Colors.white : const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(14),
          boxShadow: isUnread ? AppTheme.cardShadow : [],
          border: isUnread
              ? Border.all(color: typeColor.withOpacity(0.15), width: 0.5)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧图标
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    Center(child: Icon(typeIcon, size: 20, color: typeColor)),
                    // 未读红点
                    if (isUnread)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.dangerColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // 右侧内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题行
                    Row(
                      children: [
                        // 类型标签
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            notification.typeLabel,
                            style: TextStyle(fontSize: 10, color: typeColor, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // 内容
                    Text(
                      notification.content,
                      style: TextStyle(
                        fontSize: 13,
                        color: isUnread ? AppTheme.textSecondary : AppTheme.textHint,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 8),

                    // 时间 + 查看详情
                    Row(
                      children: [
                        Text(
                          _formatTime(notification.createdAt),
                          style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
                        ),
                        const Spacer(),
                        if (notification.postId != null && notification.postId! > 0)
                          Text(
                            '查看详情 →',
                            style: TextStyle(fontSize: 12, color: typeColor, fontWeight: FontWeight.w500),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
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
            child: Icon(Icons.notifications_none, size: 40, color: AppTheme.warningColor.withOpacity(0.4)),
          ),
          const SizedBox(height: 20),
          const Text('暂无通知', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          const Text('启事审核结果和线索回复将在这里通知你', style: TextStyle(fontSize: 13, color: AppTheme.textHint)),
        ],
      ),
    );
  }

  String _formatTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return '刚刚';
      if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
      if (diff.inHours < 24) return '${diff.inHours}小时前';
      if (diff.inDays < 7) return '${diff.inDays}天前';
      if (diff.inDays < 365) return '${date.month}月${date.day}日';
      return '${date.year}/${date.month}/${date.day}';
    } catch (e) {
      return dateStr;
    }
  }
}
