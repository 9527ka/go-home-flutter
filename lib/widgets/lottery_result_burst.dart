import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 抽奖结果弹窗爆发特效：按 rarity / isJackpot 分级
///
/// - rarity 0（谢谢参与）：不渲染（返回空）
/// - rarity 1：青色单次爆发
/// - rarity 2：金色主爆发 + 1 次烟花
/// - rarity 3 或 isJackpot：全屏金光闪 + 主爆发 + 4 次烟花 + 彩色粒子
class LotteryResultBurst extends StatefulWidget {
  final int rarity;
  final bool isJackpot;

  const LotteryResultBurst({
    super.key,
    required this.rarity,
    this.isJackpot = false,
  });

  @override
  State<LotteryResultBurst> createState() => _LotteryResultBurstState();
}

class _LotteryResultBurstState extends State<LotteryResultBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final _ResultBurstSpec _spec;

  @override
  void initState() {
    super.initState();
    _spec = _specFor(widget.rarity, widget.isJackpot);
    _ctrl = AnimationController(vsync: this, duration: _spec.duration);
    if (!_spec.skip) _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_spec.skip) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        painter: _ResultBurstPainter(progress: _ctrl.value, spec: _spec),
        size: Size.infinite,
      ),
    );
  }
}

class _ResultBurstSpec {
  final bool skip;
  final Duration duration;
  final Color mainColor;
  final int particleCount;
  final List<Color> particleColors;
  final int fireworkCount;
  final List<double> fireworkOffsets;
  /// 全屏金光闪（jackpot 专属）
  final bool jackpotFlash;
  final Color flashColor;

  const _ResultBurstSpec({
    this.skip = false,
    this.duration = const Duration(milliseconds: 1400),
    required this.mainColor,
    required this.particleCount,
    required this.particleColors,
    this.fireworkCount = 0,
    this.fireworkOffsets = const [],
    this.jackpotFlash = false,
    this.flashColor = const Color(0xFFFFD54F),
  });

  static const _ResultBurstSpec none = _ResultBurstSpec(
    skip: true,
    mainColor: Color(0x00000000),
    particleCount: 0,
    particleColors: [Color(0x00000000)],
  );
}

_ResultBurstSpec _specFor(int rarity, bool isJackpot) {
  if (isJackpot || rarity >= 3) {
    return const _ResultBurstSpec(
      duration: Duration(milliseconds: 2200),
      mainColor: Color(0xFFE040FB),
      particleCount: 60,
      particleColors: [
        Color(0xFFFF4081),
        Color(0xFFFFEB3B),
        Color(0xFF40C4FF),
        Color(0xFFE040FB),
        Color(0xFF69F0AE),
        Color(0xFFFFFFFF),
      ],
      fireworkCount: 5,
      fireworkOffsets: [0.05, 0.25, 0.45, 0.65, 0.82],
      jackpotFlash: true,
      flashColor: Color(0xFFFFE082),
    );
  }
  if (rarity == 2) {
    return const _ResultBurstSpec(
      duration: Duration(milliseconds: 1600),
      mainColor: Color(0xFFFFC107),
      particleCount: 30,
      particleColors: [
        Color(0xFFFFD54F),
        Color(0xFFFFF59D),
        Color(0xFFFFB300),
      ],
      fireworkCount: 1,
      fireworkOffsets: [0.35],
    );
  }
  if (rarity == 1) {
    return const _ResultBurstSpec(
      duration: Duration(milliseconds: 1200),
      mainColor: Color(0xFF00B0FF),
      particleCount: 16,
      particleColors: [
        Color(0xFF80DEEA),
        Color(0xFF40C4FF),
        Color(0xFFFFFFFF),
      ],
    );
  }
  // rarity 0（谢谢参与等）：不渲染
  return _ResultBurstSpec.none;
}

class _ResultBurstPainter extends CustomPainter {
  final double progress;
  final _ResultBurstSpec spec;

  _ResultBurstPainter({required this.progress, required this.spec});

  @override
  void paint(Canvas canvas, Size size) {
    // 1) 全屏金光闪（jackpot 专属）
    if (spec.jackpotFlash) {
      // 分两次闪：0.0~0.2 和 0.5~0.7
      double flashOpacity = 0;
      if (progress < 0.2) {
        flashOpacity = math.sin(progress / 0.2 * math.pi) * 0.55;
      } else if (progress > 0.5 && progress < 0.7) {
        flashOpacity = math.sin((progress - 0.5) / 0.2 * math.pi) * 0.4;
      }
      if (flashOpacity > 0.01) {
        canvas.drawRect(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Paint()
            ..shader = RadialGradient(
              center: Alignment.center,
              radius: 1.0,
              colors: [
                spec.flashColor.withValues(alpha: flashOpacity),
                spec.flashColor.withValues(alpha: flashOpacity * 0.2),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(
                Rect.fromLTWH(0, 0, size.width, size.height)),
        );
      }
    }

    final center = Offset(size.width / 2, size.height / 2);
    final minSide = math.min(size.width, size.height);

    // 2) 主爆发（从屏幕中心扩散）
    _paintSingleBurst(
      canvas,
      center,
      minSide * 0.9,
      progress,
      spec.mainColor,
      spec.particleCount,
      spec.particleColors,
      seed: 29,
      particleBaseSize: 4.5,
    );

    // 3) 烟花（各自独立中心、错开启动）
    if (spec.fireworkCount > 0 && spec.fireworkOffsets.isNotEmpty) {
      final rnd = math.Random(131);
      for (int i = 0;
          i < spec.fireworkCount && i < spec.fireworkOffsets.length;
          i++) {
        final offsetT = spec.fireworkOffsets[i];
        final localT = ((progress - offsetT) / (1 - offsetT)).clamp(0.0, 1.0);
        if (localT <= 0) continue;
        final bx = size.width * (0.15 + rnd.nextDouble() * 0.7);
        final by = size.height * (0.12 + rnd.nextDouble() * 0.55);
        final color =
            spec.particleColors[i % spec.particleColors.length];
        _paintSingleBurst(
          canvas,
          Offset(bx, by),
          minSide * 0.5,
          localT,
          color,
          22,
          spec.particleColors,
          seed: 211 + i * 17,
          particleBaseSize: 3.6,
        );
      }
    }
  }

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
    if (t == 0) return;

    // 光环（双层）
    final ringOpacity = (1 - t).clamp(0.0, 1.0);
    final mainR = baseR * 0.55 * Curves.easeOut.transform(t);
    canvas.drawCircle(
      center,
      mainR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 + 2 * (1 - t)
        ..color = ringColor.withValues(alpha: ringOpacity * 0.85),
    );
    if (t > 0.1) {
      final outerR =
          baseR * 0.75 * Curves.easeOut.transform((t - 0.1) / 0.9);
      canvas.drawCircle(
        center,
        outerR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = ringColor.withValues(alpha: ringOpacity * 0.35),
      );
    }

    // 粒子飞溅（带重力）
    final rnd = math.Random(seed);
    for (int i = 0; i < particleCount; i++) {
      final baseAngle = (i / particleCount) * 2 * math.pi;
      final angle = baseAngle + (rnd.nextDouble() - 0.5) * 0.5;
      final distSeed = 0.5 + rnd.nextDouble() * 0.5;
      final distance = baseR * 0.55 * distSeed * Curves.easeOut.transform(t);
      final gravity = math.pow(t, 2).toDouble() * baseR * 0.15;
      final pos = center + Offset(math.cos(angle), math.sin(angle)) * distance;
      final finalPos = pos.translate(0, gravity);
      final color = colors[i % colors.length];
      final opacity = (1 - t * 0.9).clamp(0.0, 1.0);
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
  bool shouldRepaint(covariant _ResultBurstPainter old) =>
      old.progress != progress;
}
