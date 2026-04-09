import 'package:flutter/material.dart';

/// 金色硬币图标 — 金币底色 + 中间小房子 logo
class CoinIcon extends StatelessWidget {
  final double size;

  const CoinIcon({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFD54F), Color(0xFFF9A825)],
        ),
        boxShadow: [
          BoxShadow(color: Color(0x40F9A825), blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: Center(
        child: Icon(Icons.home_rounded, size: size * 0.55, color: const Color(0xFF7B5800)),
      ),
    );
  }
}

/// 金币 + 数量 组合组件（用于替代纯文本币种符号）
class CoinAmount extends StatelessWidget {
  final double amount;
  final double iconSize;
  final TextStyle? textStyle;
  final String? prefix; // +/- 符号

  const CoinAmount({
    super.key,
    required this.amount,
    this.iconSize = 14,
    this.textStyle,
    this.prefix,
  });

  String get _amountText {
    final num = amount == amount.roundToDouble()
        ? '${amount.toInt()}'
        : amount.toStringAsFixed(1);
    return prefix != null ? '$prefix$num' : num;
  }

  @override
  Widget build(BuildContext context) {
    final style = textStyle ?? const TextStyle(fontSize: 14);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CoinIcon(size: iconSize),
        const SizedBox(width: 3),
        Text(_amountText, style: style),
      ],
    );
  }
}
