import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// 消息页面 — 占位实现
class MessagePage extends StatelessWidget {
  const MessagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('消息通知')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 64, color: AppTheme.textHint),
            SizedBox(height: 16),
            Text('暂无消息', style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}
