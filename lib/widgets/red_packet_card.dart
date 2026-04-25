import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'red_packet_effect.dart';

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

  /// 发送者 VIP 等级 key（发红包时快照）
  /// normal/silver/gold/platinum/diamond/supreme
  final String senderVipLevel;

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
    this.senderVipLevel = 'normal',
  });

  static const _cardRadius = Radius.circular(12);

  /// VIP 等级对应的配色（活跃态）
  static const _vipActiveGradients = <String, List<Color>>{
    'normal':   [Color(0xFFF5A623), Color(0xFFE89B1C)],
    'silver':   [Color(0xFFBDBDBD), Color(0xFF9E9E9E)],
    'gold':     [Color(0xFFFFD54F), Color(0xFFFFA726)],
    'platinum': [Color(0xFFB39DDB), Color(0xFF80DEEA)],
    'diamond':  [Color(0xFF40C4FF), Color(0xFF00B0FF), Color(0xFF18FFFF)],
    'supreme':  [Color(0xFFFF4081), Color(0xFFAA00FF), Color(0xFF40C4FF), Color(0xFFFFEB3B)],
  };

  /// 非 normal 等级的角标文字
  static const _vipBadgeText = <String, String>{
    'silver':   '白银',
    'gold':     '黄金',
    'platinum': '铂金',
    'diamond':  '钻石',
    'supreme':  '至尊',
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final isInactive = hasClaimed || isExpired || isEmpty;

    final activeColors = _vipActiveGradients[senderVipLevel] ?? _vipActiveGradients['normal']!;
    final badgeText = _vipBadgeText[senderVipLevel];
    final hasVipBadge = badgeText != null;

    final effectKey = (!isInactive)
        ? RedPacketEffectOverlay.effectKeyFromVipLevel(senderVipLevel)
        : 'none';
    final hasEffect = effectKey != 'none';

    Widget card = Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isInactive
              ? [const Color(0xFFF5DFC5), const Color(0xFFF0D4B0)]
              : activeColors,
        ),
        borderRadius: const BorderRadius.all(_cardRadius),
        // diamond/supreme 由 Overlay 自身提供 pulse 外发光；其他 VIP 保留静态阴影
        boxShadow: (hasVipBadge && !isInactive &&
                effectKey != 'diamond_skin' &&
                effectKey != 'supreme_skin')
            ? [
                BoxShadow(
                  color: activeColors.last.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
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
                if (hasVipBadge && !isInactive) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white.withOpacity(0.6), width: 0.8),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
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
    );

    if (hasEffect) {
      card = RedPacketEffectOverlay(
        effectKey: effectKey,
        borderRadius: const BorderRadius.all(_cardRadius),
        child: card,
      );
    }

    return GestureDetector(onTap: onTap, child: card);
  }

  String _statusText(AppLocalizations l) {
    if (hasClaimed) return l.get('claimed');
    if (isExpired) return l.get('red_packet_expired');
    if (isEmpty) return l.get('red_packet_empty');
    return l.get('tap_to_open');
  }
}
