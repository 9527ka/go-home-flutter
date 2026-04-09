import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';

/// Date separator row shown between messages on different days.
class DateSeparator extends StatelessWidget {
  final String dateStr;

  const DateSeparator({super.key, required this.dateStr});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    String label;
    try {
      final dt = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final msgDate = DateTime(dt.year, dt.month, dt.day);

      if (msgDate == today) {
        label = l.get('chat_date_today');
      } else if (msgDate == today.subtract(const Duration(days: 1))) {
        label = l.get('chat_date_yesterday');
      } else if (dt.year == now.year) {
        label = '${dt.month}/${dt.day}';
      } else {
        label = '${dt.year}/${dt.month}/${dt.day}';
      }
    } catch (e) {
      label = dateStr;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
              child: Divider(color: AppTheme.dividerColor, thickness: 0.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
            ),
          ),
          Expanded(
              child: Divider(color: AppTheme.dividerColor, thickness: 0.5)),
        ],
      ),
    );
  }
}
