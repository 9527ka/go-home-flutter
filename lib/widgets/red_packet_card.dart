import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// 聊天消息中的红包卡片
class RedPacketCard extends StatelessWidget {
  final int redPacketId;
  final String senderName;
  final String greeting;
  final bool isMine;
  final bool hasClaimed;
  final bool isExpired;
  final bool isEmpty;
  final VoidCallback? onTap;

  const RedPacketCard({
    super.key,
    required this.redPacketId,
    required this.senderName,
    this.greeting = '',
    this.isMine = false,
    this.hasClaimed = false,
    this.isExpired = false,
    this.isEmpty = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isInactive = hasClaimed || isExpired || isEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isInactive
                ? [const Color(0xFFF5DFC5), const Color(0xFFF0D4B0)]
                : [const Color(0xFFF5A623), const Color(0xFFE89B1C)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isInactive
                        ? const Color(0xFFE8C9A0)
                        : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.redeem,
                    color: isInactive
                        ? const Color(0xFFB8860B)
                        : Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting.isNotEmpty ? greeting : l.get('default_greeting'),
                        style: TextStyle(
                          fontSize: 14,
                          color: isInactive ? const Color(0xFF9C6B3A) : Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isInactive) ...[
                        const SizedBox(height: 2),
                        Text(
                          _statusText(l),
                          style: const TextStyle(fontSize: 11, color: Color(0xFFB8956A)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isInactive
                        ? const Color(0xFFE0C5A0)
                        : Colors.white.withOpacity(0.2),
                  ),
                ),
              ),
              child: Text(
                isInactive ? l.get('wechat_red_packet') : _statusText(l),
                style: TextStyle(
                  fontSize: 11,
                  color: isInactive
                      ? const Color(0xFFB8956A)
                      : Colors.white.withOpacity(0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusText(AppLocalizations l) {
    if (hasClaimed) return l.get('claimed');
    if (isExpired) return l.get('red_packet_expired');
    if (isEmpty) return l.get('red_packet_empty');
    return l.get('tap_to_open');
  }
}
