import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/donation.dart';
import '../../models/post_boost.dart';
import '../coin_icon.dart';

/// Activity timeline showing donation and boost records.
class PostActivityTimeline extends StatelessWidget {
  final List<DonationModel> donations;
  final List<PostBoostModel> boosts;

  const PostActivityTimeline({
    super.key,
    required this.donations,
    required this.boosts,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_ActivityItem>[];
    for (final d in donations) {
      final name = d.isAnonymous ? '匿名用户' : (d.fromUser?.nickname ?? '用户');
      items.add(_ActivityItem(
        icon: Icons.favorite,
        color: Colors.orange,
        content: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$name 支持了 ', style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
          CoinAmount(amount: d.amount, iconSize: 13, textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.orange)),
        ]),
        time: d.createdAt,
      ));
    }
    for (final b in boosts) {
      final name = b.user?.nickname ?? '用户';
      items.add(_ActivityItem(
        icon: Icons.rocket_launch,
        color: const Color(0xFF7C4DFF),
        content: Text('$name 推广置顶了 ${b.hours}小时', style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
        time: b.startAt,
      ));
    }
    items.sort((a, b) => b.time.compareTo(a.time));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '动态 (${items.length})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...items.take(10).map((a) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(a.icon, size: 16, color: a.color),
                const SizedBox(width: 8),
                Expanded(child: a.content),
                Text(
                  a.time.length > 10 ? a.time.substring(5, 16) : a.time,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _ActivityItem {
  final IconData icon;
  final Color color;
  final Widget content;
  final String time;
  const _ActivityItem({required this.icon, required this.color, required this.content, required this.time});
}
