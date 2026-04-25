import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/vip.dart';
import '../vip_decoration.dart';

/// Shared message bubble layout: nickname + time header, avatar on the side, content in the middle.
class MessageBubble extends StatelessWidget {
  final String nickname;
  final String timeText;
  final bool isMe;
  final Widget avatar;
  final Widget content;
  /// 长按回调，传递气泡在屏幕上的矩形区域（用于定位弹出菜单）
  final void Function(Rect bubbleRect)? onLongPress;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onAvatarLongPress;

  /// 发送状态徽标（如失败红感叹号、发送中菊花），仅对 isMe 消息渲染在气泡左侧
  final Widget? statusBadge;

  /// 发送者 VIP（用于昵称特效）。null 表示普通用户或未传入
  final VipBadgeModel? senderVip;

  const MessageBubble({
    super.key,
    required this.nickname,
    required this.timeText,
    required this.isMe,
    required this.avatar,
    required this.content,
    this.onLongPress,
    this.onAvatarTap,
    this.onAvatarLongPress,
    this.statusBadge,
    this.senderVip,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: onLongPress != null
          ? (_) {
              final box = context.findRenderObject() as RenderBox;
              final pos = box.localToGlobal(Offset.zero);
              onLongPress!(Rect.fromLTWH(pos.dx, pos.dy, box.size.width, box.size.height));
            }
          : null,
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  Flexible(
                    child: VipNickname(
                      vip: senderVip,
                      text: nickname,
                      baseStyle: const TextStyle(fontSize: 11, color: AppTheme.textHint),
                    ),
                  ),
                  if (senderVip != null && !(senderVip!.isNormal)) ...[
                    const SizedBox(width: 4),
                    VipLevelBadge(vip: senderVip, fontSize: 9),
                  ],
                  const SizedBox(width: 6),
                  Text(
                    timeText,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
                  ),
                ],
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
                    onLongPress: onAvatarLongPress,
                    child: avatar,
                  ),
                  const SizedBox(width: 8),
                ],
                if (isMe && statusBadge != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 6, top: 10),
                    child: statusBadge!,
                  ),
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
