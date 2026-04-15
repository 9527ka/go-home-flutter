import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/chat_message.dart';

/// Shows a bottom sheet with message actions (copy, report, cancel).
///
/// [msg] - the message model
/// [isMe] - whether this message was sent by the current user
/// [onReport] - callback to report the message
void showMessageActions({
  required BuildContext context,
  required ChatMessageModel msg,
  required bool isMe,
  required VoidCallback onReport,
}) {
  final l = AppLocalizations.of(context)!;
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Copy text (only for text messages)
            if (msg.msgType == ChatMsgType.text)
              ListTile(
                leading:
                    const Icon(Icons.copy, color: AppTheme.textSecondary),
                title: Text(l.get('copy_text')),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: msg.content));
                  Fluttertoast.showToast(msg: l.get('message_copied'));
                },
              ),
            // Report message (not own messages)
            if (!isMe)
              ListTile(
                leading: const Icon(Icons.flag_outlined,
                    color: AppTheme.warningColor),
                title: Text(l.get('chat_report')),
                onTap: () {
                  Navigator.pop(ctx);
                  onReport();
                },
              ),
            // Cancel
            ListTile(
              leading: const Icon(Icons.close, color: AppTheme.textHint),
              title: Text(l.get('cancel')),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    ),
  );
}
