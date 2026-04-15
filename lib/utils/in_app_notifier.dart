import 'package:flutter/material.dart';

/// 应用内消息横幅兜底（仅前台 + App 有 Scaffold 时生效）。
///
/// 用于在系统通知失效（未授权 / iOS 静音键 / Android 无原生实现）时，
/// 保证用户仍能在 App 内看到新消息提示。通过全局 `scaffoldMessengerKey`
/// 触发 SnackBar，不依赖平台通知权限。
class InAppNotifier {
  /// 全局 ScaffoldMessenger key，由 `main.dart` 注入到 `MaterialApp`。
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// 显示一条应用内顶部横幅。
  /// [title] 发送方昵称 / 事件标题
  /// [body]  消息预览 / 事件描述
  static void show({required String title, required String body}) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) return;

    // 先隐藏当前 SnackBar，避免堆积
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                body,
                style: const TextStyle(fontSize: 13, color: Colors.white),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
