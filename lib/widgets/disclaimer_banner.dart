import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// 免责声明横幅 — 必须在首页和详情页展示
class DisclaimerBanner extends StatefulWidget {
  const DisclaimerBanner({super.key});

  @override
  State<DisclaimerBanner> createState() => _DisclaimerBannerState();
}

class _DisclaimerBannerState extends State<DisclaimerBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF8E1), Color(0xFFFFF3CD)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE082), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFFFC107).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.shield_outlined, size: 16, color: Color(0xFFE65100)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppLocalizations.of(context)?.get('disclaimer') ?? '本平台不保证信息真实性，如遇紧急情况请立即拨打110报警',
              style: const TextStyle(fontSize: 12, color: Color(0xFF795548), height: 1.3),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() => _dismissed = true),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: const Color(0xFF795548).withOpacity(0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.close, size: 13, color: Color(0xFF795548)),
            ),
          ),
        ],
      ),
    );
  }
}
