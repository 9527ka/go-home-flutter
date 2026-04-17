import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../l10n/app_localizations.dart';
import '../../models/chat_message.dart';
import '../../providers/chat_provider.dart';
import '../../providers/conversation_provider.dart';
import 'chat_picker_page.dart';

/// 选择目标会话后转发消息
Future<bool> forwardMessages(BuildContext context, List<ChatMessageModel> messages) async {
  if (messages.isEmpty) return false;
  final l = AppLocalizations.of(context)!;

  // 选择目标会话
  final result = await Navigator.push<Map<String, dynamic>>(
    context,
    MaterialPageRoute(builder: (_) => ChatPickerPage(title: l.get('msg_forward'))),
  );
  if (result == null || !context.mounted) return false;

  final targetType = result['targetType'] as String;
  final targetId = result['targetId'] as int;
  final targetName = result['name'] as String;

  // 确认对话框
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text('${l.get("msg_forward")} ${messages.length > 1 ? "${messages.length}条消息" : ""} → $targetName?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.get('cancel'))),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.get('confirm'))),
      ],
    ),
  );
  if (confirm != true || !context.mounted) return false;

  final chatProvider = context.read<ChatProvider>();
  final convProvider = context.read<ConversationProvider>();

  for (final msg in messages) {
    if (msg.msgType == ChatMsgType.system) continue;

    final isTextLike = msg.msgType == ChatMsgType.text || msg.msgType == ChatMsgType.contactCard;

    if (targetType == 'private') {
      if (isTextLike) {
        chatProvider.sendPrivateMessage(targetId, msg.content);
      } else {
        chatProvider.sendPrivateMediaMessage(
          toUserId: targetId,
          msgType: msg.msgTypeStr,
          mediaUrl: msg.mediaUrl,
          thumbUrl: msg.thumbUrl,
          content: msg.content,
          mediaInfo: msg.mediaInfo,
        );
      }
    } else {
      if (isTextLike) {
        chatProvider.sendGroupMessage(targetId, msg.content);
      } else {
        chatProvider.sendGroupMediaMessage(
          groupId: targetId,
          msgType: msg.msgTypeStr,
          mediaUrl: msg.mediaUrl,
          thumbUrl: msg.thumbUrl,
          content: msg.content,
          mediaInfo: msg.mediaInfo,
        );
      }
    }
  }

  // 更新会话列表
  final lastMsg = messages.last;
  String preview = lastMsg.content;
  if (lastMsg.msgType == ChatMsgType.image) preview = '[图片]';
  if (lastMsg.msgType == ChatMsgType.video) preview = '[视频]';
  if (lastMsg.msgType == ChatMsgType.voice) preview = '[语音]';
  convProvider.onMessageSent(
    targetId: targetId,
    targetType: targetType,
    content: preview,
    msgType: lastMsg.msgTypeStr,
    name: targetName,
    avatar: result['avatar'] as String? ?? '',
  );

  Fluttertoast.showToast(msg: l.get('forward_success'));
  return true;
}
