import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 红包开包爆发特效（按 VIP 动效 key 分级）
///
/// 结构：一次性播放的全屏覆盖层，从中心扩散的光圈 + 粒子飞溅；
/// supreme_skin 额外叠加 3 次错开的"烟花"（不同位置重复爆发）。
/// 播放完成后回调 [onComplete]。
class RedPacketOpenBurst extends StatefulWidget {
  final String effectKey;
  final VoidCallback? onComplete;

  const RedPacketOpenBurst({
    super.key,
    required this.effectKey,
    this.onComplete,
  });

  @override
  State<RedPacketOpenBurst> createState() => _RedPacketOpenBurstState();
}

class _RedPacketOpenBurstState extends State<RedPacketOpenBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final _BurstConfig _cfg;

  @override
  void initState() {
    super.initState();
    _cfg = _configFor(widget.effectKey);
    _ctrl = AnimationController(vsync: this, duration: _cfg.duration);
    _ctrl.forward().then((_) => widget.onComplete?.call());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _BurstPainter(progress: _ctrl.value, cfg: _cfg),
        size: Size.infinite,
      ),
    );
  }
}

class _BurstConfig {
  final Duration duration;
  final Color ringColor;
  final int particleCount;
  final List<Color> particleColors;
  /// 额外叠加的烟花爆点数（每个点是独立 burst 子中心）
  final int fireworkBursts;
  /// 烟花每次爆发相对于主时间线的启动偏移（0..1）
  final List<double> fireworkOffsets;

  const _BurstConfig({
    this.duration = const Duration(milliseconds: 900),
    required this.ringColor,
    required this.particleCount,
    required this.particleColors,
    this.fireworkBursts = 0,
    this.fireworkOffsets = const [],
  });
}

_BurstConfig _configFor(String key) {
  switch (key) {
    case 'silver_skin':
      return const _BurstConfig(
        ringColor: Color(0xFFE0E0E0),
        particleCount: 14,
        particleColors: [Color(0xFFFFFFFF), Color(0xFFE0E0E0)],
      );
    case 'gold_skin':
      return const _BurstConfig(
        duration: Duration(milliseconds: 1000),
        ringColor: Color(0xFFFFC107),
        particleCount: 22,
        particleColors: [
          Color(0xFFFFD54F),
          Color(0xFFFFF59D),
          Color(0xFFFFB300),
        ],
      );
    case 'platinum_skin':
      return const _BurstConfig(
        duration: Duration(milliseconds: 1100),
        ringColor: Color(0xFFE1BEE7),
        particleCount: 28,
        particleColors: [
          Color(0xFFE1BEE7),
          Color(0xFF80DEEA),
          Color(0xFFFFF59D),
          Color(0xFFB39DDB),
        ],
      );
    case 'diamond_skin':
      return const _BurstConfig(
        duration: Duration(milliseconds: 1200),
        ringColor: Color(0xFF40C4FF),
        particleCount: 36,
        particleColors: [
          Color(0xFF40C4FF),
          Color(0xFFFFFFFF),
          Color(0xFF80D8FF),
          Color(0xFFB3E5FC),
        ],
        fireworkBursts: 2,
        fireworkOffsets: [0.15, 0.45],
      );
    case 'supreme_skin':
      return const _BurstConfig(
        duration: Duration(milliseconds: 1400),
        ringColor: Color(0xFFE040FB),
        particleCount: 48,
        particleColors: [
          Color(0xFFFF4081),
          Color(0xFFFFEB3B),
          Color(0xFF40C4FF),
          Color(0xFFE040FB),
          Color(0xFF69F0AE),
          Color(0xFFFFFFFF),
        ],
        fireworkBursts: 4,
        fireworkOffsets: [0.1, 0.3, 0.55, 0.8],
      );
    default:
      // normal：温和的金色爆发
      return const _BurstConfig(
        duration: Duration(milliseconds: 800),
        ringColor: Color(0xFFECC88A),
        particleCount: 10,
        particleColors: [Color(0xFFECC88A), Color(0xFFFFF59D)],
      );
  }
}

class _BurstPainter extends CustomPainter {
  final double progress;
  final _BurstConfig cfg;

  _BurstPainter({required this.progress, required this.cfg});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final minSide = math.min(size.width, size.height);

    // 1) 主爆发：从中心扩散的光圈 + 粒子飞溅
    _paintSingleBurst(
      canvas,
      center,
      minSide,
      progress,
      cfg.ringColor,
      cfg.particleCount,
      cfg.particleColors,
      seed: 31,
    );

    // 2) 烟花爆点：在屏幕不同位置叠加较小的爆发
    if (cfg.fireworkBursts > 0 && cfg.fireworkOffsets.isNotEmpty) {
      final rnd = math.Random(97);
      for (int i = 0; i < cfg.fireworkBursts && i < cfg.fireworkOffsets.length;
          i++) {
        final offsetT = cfg.fireworkOffsets[i];
        final localT = ((progress - offsetT) / (1 - offsetT)).clamp(0.0, 1.0);
        if (localT <= 0) continue;
        final bx = size.width * (0.2 + rnd.nextDouble() * 0.6);
        final by = size.height * (0.2 + rnd.nextDouble() * 0.5);
        _paintSingleBurst(
          canvas,
          Offset(bx, by),
          minSide * 0.6,
          localT,
          cfg.particleColors[i % cfg.particleColors.length],
          18,
          cfg.particleColors,
          seed: 101 + i * 13,
          particleBaseSize: 3.2,
        );
      }
    }
  }

  /// 一次爆发（光圈 + 粒子飞溅）
  void _paintSingleBurst(
    Canvas canvas,
    Offset center,
    double baseR,
    double t,
    Color ringColor,
    int particleCount,
    List<Color> colors, {
    int seed = 0,
    double particleBaseSize = 4.0,
  }) {
    if (t <= 0 || t >= 1) {
      // t=0 或 t=1 时不绘制（减少一帧）
      if (t == 0) return;
    }

    // 扩散光环（两圈：主圈 + 次圈）
    final ringOpacity = (1 - t).clamp(0.0, 1.0);
    final mainR = baseR * 0.6 * Curves.easeOut.transform(t);
    canvas.drawCircle(
      center,
      mainR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 + 2 * (1 - t)
        ..color = ringColor.withValues(alpha: ringOpacity * 0.9),
    );
    if (t > 0.1) {
      final outerR = baseR * 0.8 * Curves.easeOut.transform((t - 0.1) / 0.9);
      canvas.drawCircle(
        center,
        outerR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = ringColor.withValues(alpha: ringOpacity * 0.4),
      );
    }

    // 粒子飞溅
    final rnd = math.Random(seed);
    for (int i = 0; i < particleCount; i++) {
      final baseAngle = (i / particleCount) * 2 * math.pi;
      final angle = baseAngle + (rnd.nextDouble() - 0.5) * 0.5;
      final distSeed = 0.5 + rnd.nextDouble() * 0.5;
      final distance = baseR * 0.55 * distSeed * Curves.easeOut.transform(t);
      // 带轻微重力
      final gravity = math.pow(t, 2).toDouble() * baseR * 0.1;
      final pos =
          center + Offset(math.cos(angle), math.sin(angle)) * distance;
      final finalPos = pos.translate(0, gravity);
      final color = colors[i % colors.length];
      final opacity = (1 - t * 0.95).clamp(0.0, 1.0);
      final size = particleBaseSize * (1 - 0.4 * t);

      canvas.drawCircle(
        finalPos,
        size,
        Paint()
          ..color = color.withValues(alpha: opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.drawCircle(
        finalPos,
        size * 0.45,
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => old.progress != progress;
}
