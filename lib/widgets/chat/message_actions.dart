import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../l10n/app_localizations.dart';
import '../../models/chat_message.dart';

/// 微信风格：消息上方浮动操作栏
void showMessageActions({
  required BuildContext context,
  required ChatMessageModel msg,
  required bool isMe,
  required Rect bubbleRect,
  required VoidCallback onReport,
  VoidCallback? onRecall,
  VoidCallback? onDelete,
  VoidCallback? onForward,
  VoidCallback? onMultiSelect,
  VoidCallback? onQuote,
  bool isAdmin = false,
  bool? canRecall,
}) {
  if (msg.msgType == ChatMsgType.system) return;

  final l = AppLocalizations.of(context)!;
  final actions = <_ActionItem>[];

  // 复制
  if (msg.msgType == ChatMsgType.text || msg.msgType == ChatMsgType.contactCard) {
    actions.add(_ActionItem(
      icon: Icons.content_copy,
      label: l.get('copy_text'),
      onTap: () {
        Clipboard.setData(ClipboardData(text: msg.content));
        Fluttertoast.showToast(msg: l.get('message_copied'));
      },
    ));
  }

  // 转发
  if (onForward != null) {
    actions.add(_ActionItem(
      icon: Icons.share_outlined,
      label: l.get('msg_forward'),
      onTap: () => onForward(),
    ));
  }

  // 引用
  if (onQuote != null && (msg.msgType == ChatMsgType.text || msg.msgType == ChatMsgType.image || msg.msgType == ChatMsgType.video)) {
    actions.add(_ActionItem(
      icon: Icons.reply,
      label: l.get('msg_quote'),
      onTap: () => onQuote(),
    ));
  }

  // 撤回
  bool showRecall = false;
  if (onRecall != null) {
    if (canRecall != null) {
      showRecall = canRecall && (isAdmin || (isMe && _isWithin2Minutes(msg)));
    } else {
      showRecall = isMe && _isWithin2Minutes(msg);
    }
  }
  if (showRecall) {
    actions.add(_ActionItem(
      icon: Icons.replay,
      label: l.get('msg_recall'),
      onTap: () => onRecall!(),
    ));
  }

  // 删除
  if (onDelete != null) {
    actions.add(_ActionItem(
      icon: Icons.delete_outline,
      label: l.get('msg_delete'),
      onTap: () => onDelete(),
    ));
  }

  // 多选
  if (onMultiSelect != null) {
    actions.add(_ActionItem(
      icon: Icons.playlist_add_check,
      label: l.get('msg_multi_select'),
      onTap: () => onMultiSelect(),
    ));
  }

  // 举报
  if (!isMe) {
    actions.add(_ActionItem(
      icon: Icons.report_outlined,
      label: l.get('chat_report'),
      onTap: () => onReport(),
    ));
  }

  if (actions.isEmpty) return;

  Navigator.of(context).push(_PopupRoute(
    bubbleRect: bubbleRect,
    actions: actions,
  ));
}

bool _isWithin2Minutes(ChatMessageModel msg) {
  if (msg.createdAt.isEmpty) return false;
  try {
    final sentAt = DateTime.parse(msg.createdAt);
    return DateTime.now().difference(sentAt).inMinutes < 2;
  } catch (_) {
    return false;
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionItem({required this.icon, required this.label, required this.onTap});
}

class _PopupRoute extends PopupRoute<void> {
  final Rect bubbleRect;
  final List<_ActionItem> actions;

  _PopupRoute({required this.bubbleRect, required this.actions});

  @override
  Color? get barrierColor => Colors.black12;
  @override
  bool get barrierDismissible => true;
  @override
  String? get barrierLabel => null;
  @override
  Duration get transitionDuration => const Duration(milliseconds: 150);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return _PopupContent(bubbleRect: bubbleRect, actions: actions, animation: animation);
  }
}

class _PopupContent extends StatelessWidget {
  final Rect bubbleRect;
  final List<_ActionItem> actions;
  final Animation<double> animation;

  const _PopupContent({required this.bubbleRect, required this.actions, required this.animation});

  static const _cols = 5;
  static const _itemW = 56.0;
  static const _itemH = 50.0;
  static const _hPad = 6.0;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    final int rows = (actions.length / _cols).ceil();
    final int colsInFirstRow = actions.length >= _cols ? _cols : actions.length;
    final menuWidth = colsInFirstRow * _itemW + _hPad * 2;
    final menuHeight = rows * _itemH + 8; // 上下各 4pt 内边距

    double left = bubbleRect.center.dx - menuWidth / 2;
    left = left.clamp(8.0, screenWidth - menuWidth - 8.0);

    final bool showAbove = bubbleRect.top > menuHeight + 50;
    final double top = showAbove
        ? bubbleRect.top - menuHeight - 8
        : bubbleRect.bottom + 8;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => Navigator.of(context).pop(),
      child: Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            child: FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.85, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                ),
                alignment: showAbove ? Alignment.bottomCenter : Alignment.topCenter,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: menuWidth,
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: _hPad),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.start,
                      children: actions.map((a) => _buildBtn(context, a)).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBtn(BuildContext context, _ActionItem action) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.of(context).pop();
        action.onTap();
      },
      child: SizedBox(
        width: _itemW,
        height: _itemH,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(action.icon, size: 20, color: Colors.white),
            const SizedBox(height: 4),
            Text(
              action.label,
              style: const TextStyle(fontSize: 10, color: Colors.white70, height: 1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
