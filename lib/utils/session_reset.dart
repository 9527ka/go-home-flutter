import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pages/chat/private_chat_page.dart';
import '../pages/group/group_chat_page.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/conversation_provider.dart';
import '../providers/friend_provider.dart';
import '../providers/interaction_provider.dart';
import '../providers/notification_provider.dart';

/// 切换账号/登出时的会话级数据清理。
///
/// 背景：同一设备退出账号后，新账号登录若不彻底清理 Provider 内存状态
/// 与本地 prefs，就会把上一个账号的会话列表 / 好友 / 未读 / 置顶 / 免打扰
/// 暴露给新账号，造成隐私泄漏。
///
/// 本函数负责：
/// 1. 清空核心 Provider 的内存状态（Conversation / Chat / Friend / Notification / Interaction）
/// 2. 清空 per-user / per-conversation 的本地 prefs（mute、pin、group_cleared_at 等）
/// 3. 调用 AuthProvider.logout 清 token 与认证态
///
/// 使用：[isDeleteAccount] = true 时表示注销账号（调用方已经走过服务端删除流程），
/// 否则视为普通退出登录。两者本地清理逻辑相同，仅用于日志区分。
Future<void> performLogout(
  BuildContext context, {
  bool isDeleteAccount = false,
}) async {
  // 1. 先清 Provider 内存状态（必须在 auth.logout 之前，防止 notify 级联触发网络请求）
  //    使用 listen:false 避免在异步上下文中订阅 Widget 变化
  context.read<ChatProvider>().resetSession();
  context.read<ConversationProvider>().resetSession();
  context.read<FriendProvider>().resetSession();
  context.read<NotificationProvider>().resetSession();
  context.read<InteractionProvider>().clear();

  // 清除进程内聊天消息缓存（私聊 + 群聊），防止新账号看到旧账号的消息
  PrivateChatPage.invalidateAllCaches();
  GroupChatPage.invalidateAllCaches();

  // 2. 清 per-conversation 本地 prefs（免打扰 / 置顶 / 清空聊天时间戳等）
  await _clearSessionPreferences();

  // 3. 清 token + 调 logout 接口（注销 device token、清 posts/chat cache）
  if (context.mounted) {
    await context.read<AuthProvider>().logout();
  }
}

/// 清除所有与"会话/用户"绑定的 SharedPreferences key。
/// 保留跨账号的全局偏好（语言、EULA、记住我等）。
Future<void> _clearSessionPreferences() async {
  final prefs = await SharedPreferences.getInstance();
  final keys = prefs.getKeys();
  final removable = keys.where((k) {
    return k.startsWith('conv_mute_') ||
        k.startsWith('conv_pin_') ||
        k == 'conv_pinned_keys' ||
        k.startsWith('group_cleared_at_') ||
        k == 'go_home_last_read_chat_id';
  }).toList();
  for (final k in removable) {
    await prefs.remove(k);
  }
}
