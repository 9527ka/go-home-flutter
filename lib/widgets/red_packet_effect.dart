import 'dart:math' as math;
import 'package:flutter/material.dart';

/// VIP 红包皮肤特效覆盖层
///
/// 在给定 child（红包卡片/弹窗主体）之上叠加一层动画：
///   - silver_skin:   银色流光扫过
///   - gold_skin:     金色流光扫过
///   - platinum_skin: 渐变流光扫过
///   - diamond_skin:  冰蓝流光 + 外层脉冲发光
///   - supreme_skin:  彩虹流光 + 旋转光晕边框 + 脉冲
///   - none/''/其它:   直接返回 child，无副作用
class RedPacketEffectOverlay extends StatefulWidget {
  /// 动效 key，取自 vip_levels.red_packet_effect_key
  final String effectKey;
  /// 圆角（用来裁剪流光层 + 外发光 shadow 形状）
  final BorderRadius borderRadius;
  final Widget child;

  /// VIP 等级 → effectKey 的前端兜底映射。
  ///
  /// 后端 RedPacket 广播消息 JSON 仅快照 sender_vip_level，未含 effect_key，
  /// 前端据此映射推导出动效 key（与 migrations/029_add_vip_system.sql 保持一致）。
  static String effectKeyFromVipLevel(String vipLevel) {
    switch (vipLevel) {
      case 'silver':   return 'silver_skin';
      case 'gold':     return 'gold_skin';
      case 'platinum': return 'platinum_skin';
      case 'diamond':  return 'diamond_skin';
      case 'supreme':  return 'supreme_skin';
      default:         return 'none';
    }
  }

  const RedPacketEffectOverlay({
    super.key,
    required this.effectKey,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    required this.child,
  });

  @override
  State<RedPacketEffectOverlay> createState() => _RedPacketEffectOverlayState();
}

class _RedPacketEffectOverlayState extends State<RedPacketEffectOverlay>
    with TickerProviderStateMixin {
  late _EffectConfig _cfg;
  AnimationController? _sweep;
  AnimationController? _halo;
  AnimationController? _pulse;
  AnimationController? _particles;

  void _initControllers() {
    if (_cfg.isNone) return;
    _sweep = AnimationController(vsync: this, duration: _cfg.sweepDuration)
      ..repeat();
    if (_cfg.rotatingHalo) {
      _halo = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 4),
      )..repeat();
    }
    if (_cfg.pulse) {
      _pulse = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..repeat(reverse: true);
    }
    if (_cfg.particleCount > 0) {
      _particles = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 4000),
      )..repeat();
    }
  }

  void _disposeControllers() {
    _sweep?.dispose();
    _halo?.dispose();
    _pulse?.dispose();
    _particles?.dispose();
    _sweep = _halo = _pulse = _particles = null;
  }

  @override
  void initState() {
    super.initState();
    _cfg = _configFor(widget.effectKey);
    _initControllers();
  }

  @override
  void didUpdateWidget(covariant RedPacketEffectOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.effectKey != widget.effectKey) {
      _disposeControllers();
      _cfg = _configFor(widget.effectKey);
      _initControllers();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cfg.isNone) return widget.child;

    // 注意：ClipRRect 只裁 shine/粒子 层，保留 child 自带的 boxShadow 不被吃掉
    final overlayLayers = <Widget>[
      Positioned.fill(
        child: IgnorePointer(
          child: ClipRRect(
            borderRadius: widget.borderRadius,
            child: AnimatedBuilder(
              animation: _sweep!,
              builder: (context, _) {
                return CustomPaint(
                  painter: _ShinePainter(
                    progress: _sweep!.value,
                    colors: _cfg.sweepColors,
                    widthFactor: _cfg.sweepWidthFactor,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ];

    if (_particles != null) {
      overlayLayers.add(
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: widget.borderRadius,
              child: AnimatedBuilder(
                animation: _particles!,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _ParticlePainter(
                      progress: _particles!.value,
                      count: _cfg.particleCount,
                      colors: _cfg.particleColors,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    Widget content = Stack(
      children: [
        widget.child,
        ...overlayLayers,
      ],
    );

    if (_cfg.rotatingHalo) {
      content = AnimatedBuilder(
        animation: _halo!,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              gradient: SweepGradient(
                colors: const [
                  Color(0xFFFF4081), Color(0xFFFFEB3B),
                  Color(0xFF40C4FF), Color(0xFFAA00FF),
                  Color(0xFFFF4081),
                ],
                transform: GradientRotation(_halo!.value * 2 * math.pi),
              ),
            ),
            child: child,
          );
        },
        child: content,
      );
    }

    if (_cfg.pulse) {
      content = AnimatedBuilder(
        animation: _pulse!,
        builder: (context, child) {
          final t = _pulse!.value;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              boxShadow: [
                BoxShadow(
                  color: _cfg.glowColor.withValues(alpha: 0.3 + 0.45 * t),
                  blurRadius: 8 + 12 * t,
                  spreadRadius: 1 + 2 * t,
                ),
              ],
            ),
            child: child,
          );
        },
        child: content,
      );
    }

    return content;
  }
}

class _EffectConfig {
  final bool isNone;
  final Duration sweepDuration;
  final List<Color> sweepColors;
  final double sweepWidthFactor;
  final bool rotatingHalo;
  final bool pulse;
  final Color glowColor;
  /// 粒子数量（0 = 不叠加粒子层）
  final int particleCount;
  /// 粒子候选颜色（按粒子索引轮询）
  final List<Color> particleColors;

  const _EffectConfig({
    this.isNone = false,
    this.sweepDuration = const Duration(milliseconds: 2200),
    this.sweepColors = const [
      Color(0x00FFFFFF),
      Color(0x99FFFFFF),
      Color(0x00FFFFFF),
    ],
    this.sweepWidthFactor = 0.45,
    this.rotatingHalo = false,
    this.pulse = false,
    this.glowColor = const Color(0xFFFFFFFF),
    this.particleCount = 0,
    this.particleColors = const [Color(0xFFFFFFFF)],
  });

  static const _EffectConfig none = _EffectConfig(isNone: true);
}

_EffectConfig _configFor(String key) {
  switch (key) {
    case 'silver_skin':
      return const _EffectConfig(
        sweepDuration: Duration(milliseconds: 2400),
        sweepColors: [
          Color(0x00FFFFFF),
          Color(0x99E0E0E0),
          Color(0x00FFFFFF),
        ],
        sweepWidthFactor: 0.5,
        particleCount: 6,
        particleColors: [Color(0xFFFFFFFF), Color(0xFFE0E0E0)],
      );
    case 'gold_skin':
      return const _EffectConfig(
        sweepDuration: Duration(milliseconds: 2000),
        sweepColors: [
          Color(0x00FFE082),
          Color(0xCCFFF59D),
          Color(0x00FFE082),
        ],
        sweepWidthFactor: 0.45,
        particleCount: 8,
        particleColors: [Color(0xFFFFF59D), Color(0xFFFFC107), Color(0xFFFFE082)],
      );
    case 'platinum_skin':
      return const _EffectConfig(
        sweepDuration: Duration(milliseconds: 1800),
        sweepColors: [
          Color(0x0080DEEA),
          Color(0xCCE1BEE7),
          Color(0x0080DEEA),
        ],
        sweepWidthFactor: 0.45,
        particleCount: 10,
        particleColors: [Color(0xFFE1BEE7), Color(0xFF80DEEA), Color(0xFFFFF59D)],
      );
    case 'diamond_skin':
      return const _EffectConfig(
        sweepDuration: Duration(milliseconds: 1600),
        sweepColors: [
          Color(0x0080D8FF),
          Color(0xDD40C4FF),
          Color(0x0080D8FF),
        ],
        sweepWidthFactor: 0.4,
        pulse: true,
        glowColor: Color(0xFF40C4FF),
        particleCount: 14,
        particleColors: [Color(0xFFFFFFFF), Color(0xFF40C4FF), Color(0xFF80D8FF)],
      );
    case 'supreme_skin':
      return const _EffectConfig(
        sweepDuration: Duration(milliseconds: 1400),
        sweepColors: [
          Color(0x00FFEB3B),
          Color(0xEEFFFFFF),
          Color(0x00FFEB3B),
        ],
        sweepWidthFactor: 0.38,
        rotatingHalo: true,
        pulse: true,
        glowColor: Color(0xFFE040FB),
        particleCount: 20,
        particleColors: [
          Color(0xFFFF4081),
          Color(0xFFFFEB3B),
          Color(0xFF40C4FF),
          Color(0xFFE040FB),
          Color(0xFFFFFFFF),
        ],
      );
    default:
      return _EffectConfig.none;
  }
}

class _ShinePainter extends CustomPainter {
  final double progress;
  final List<Color> colors;
  final double widthFactor;

  _ShinePainter({
    required this.progress,
    required this.colors,
    required this.widthFactor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bandWidth = size.width * widthFactor;
    // 从 -bandWidth 扫到 size.width（保证完全穿过）
    final travel = size.width + bandWidth;
    final x = -bandWidth + travel * progress;

    final shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
      stops: const [0.0, 0.5, 1.0],
    ).createShader(Rect.fromLTWH(x, 0, bandWidth, size.height));

    final paint = Paint()..shader = shader;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ShinePainter old) =>
      old.progress != progress ||
      old.widthFactor != widthFactor ||
      old.colors != colors;
}

class _ParticlePainter extends CustomPainter {
  final double progress;
  final int count;
  final List<Color> colors;

  _ParticlePainter({
    required this.progress,
    required this.count,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 使用固定种子 Random：保证同一粒子每帧位置可预测、仅随 progress 演进
    final rnd = math.Random(count * 31 + 7);
    for (int i = 0; i < count; i++) {
      final seedX = rnd.nextDouble();
      final seedPhase = rnd.nextDouble();
      final seedSpeed = 0.8 + rnd.nextDouble() * 0.6;
      final seedSize = 1.4 + rnd.nextDouble() * 2.2;
      final seedDrift = (rnd.nextDouble() - 0.5) * 0.25;
      final color = colors[i % colors.length];

      // 粒子纵向位置：localT 从 0 → 1 自下向上循环
      final localT = ((progress * seedSpeed) + seedPhase) % 1.0;
      final x = size.width *
          (seedX + seedDrift * math.sin(localT * math.pi * 2)).clamp(0.0, 1.0);
      final y = size.height * (1.0 - localT);

      // 两端淡入淡出
      double opacity;
      if (localT < 0.2) {
        opacity = localT / 0.2;
      } else if (localT > 0.8) {
        opacity = (1.0 - localT) / 0.2;
      } else {
        opacity = 1.0;
      }
      opacity = (opacity * 0.9).clamp(0.0, 1.0);
      if (opacity < 0.02) continue;

      // 柔光
      canvas.drawCircle(
        Offset(x, y),
        seedSize,
        Paint()
          ..color = color.withValues(alpha: opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4),
      );
      // 高亮核心
      canvas.drawCircle(
        Offset(x, y),
        seedSize * 0.45,
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) =>
      old.progress != progress || old.count != count;
}
