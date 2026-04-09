import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// Shared message bubble layout: nickname + time header, avatar on the side, content in the middle.
class MessageBubble extends StatelessWidget {
  final String nickname;
  final String timeText;
  final bool isMe;
  final Widget avatar;
  final Widget content;
  final VoidCallback? onLongPress;
  final VoidCallback? onAvatarTap;

  const MessageBubble({
    super.key,
    required this.nickname,
    required this.timeText,
    required this.isMe,
    required this.avatar,
    required this.content,
    this.onLongPress,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(
                bottom: 2,
                left: isMe ? 2 : 46,
                right: isMe ? 46 : 2,
              ),
              child: Text(
                '$nickname  $timeText',
                style:
                    const TextStyle(fontSize: 11, color: AppTheme.textHint),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment:
                  isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                if (!isMe) ...[
                  GestureDetector(
                    onTap: onAvatarTap,
                    child: avatar,
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(child: content),
                if (isMe) ...[
                  const SizedBox(width: 8),
                  avatar,
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
