import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/vip.dart';

/// VIP 头像装饰（边框效果）
/// 用法：VipAvatarFrame(vip: user.vip, child: AvatarWidget(...))
class VipAvatarFrame extends StatelessWidget {
  final VipBadgeModel? vip;
  final Widget child;
  final double borderWidth;

  const VipAvatarFrame({
    super.key,
    required this.vip,
    required this.child,
    this.borderWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    final effect = vip?.badgeEffectKey ?? 'none';
    if (vip == null || effect == 'none') return child;

    switch (effect) {
      case 'gray_border':
        return _simpleBorder(const Color(0xFFB0B0B0));
      case 'gold_border':
        // 黄金：静态金边 + 呼吸高光
        return _GlowPulseFrame(
          color: const Color(0xFFFFB300),
          borderWidth: borderWidth,
          duration: const Duration(milliseconds: 1800),
          child: child,
        );
      case 'gradient_border':
        // 铂金：彩色渐变边沿缓慢流动
        return _RotatingHaloFrame(
          colors: const [
            Color(0xFFB39DDB), Color(0xFF80DEEA), Color(0xFFFFF59D),
            Color(0xFFB39DDB),
          ],
          borderWidth: borderWidth,
          duration: const Duration(milliseconds: 5000),
          child: child,
        );
      case 'glow_pulse':
        // 钻石：加强脉冲（更强 blur + 更快节奏）
        return _GlowPulseFrame(
          color: const Color(0xFF40C4FF),
          borderWidth: borderWidth,
          duration: const Duration(milliseconds: 1200),
          intensity: 1.5,
          child: child,
        );
      case 'rotating_halo':
        // 至尊：旋转彩虹光晕 + 随机闪烁星点粒子
        return _SparkleSupremeFrame(
          colors: const [
            Color(0xFFFF4081), Color(0xFFFFEB3B), Color(0xFF40C4FF),
            Color(0xFFAA00FF), Color(0xFFFF4081),
          ],
          borderWidth: borderWidth,
          child: child,
        );
      default:
        return child;
    }
  }

  Widget _simpleBorder(Color color) {
    return Container(
      padding: EdgeInsets.all(borderWidth),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: borderWidth),
      ),
      child: child,
    );
  }
}

class _GlowPulseFrame extends StatefulWidget {
  final Color color;
  final double borderWidth;
  final Widget child;
  final Duration duration;
  /// 强度倍率（钻石用 >1 表示更强）
  final double intensity;

  const _GlowPulseFrame({
    required this.color,
    required this.borderWidth,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
    this.intensity = 1.0,
  });

  @override
  State<_GlowPulseFrame> createState() => _GlowPulseFrameState();
}

class _GlowPulseFrameState extends State<_GlowPulseFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);
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
      builder: (context, child) {
        final t = _ctrl.value;
        final k = widget.intensity;
        final glow = (0.3 + 0.7 * t) * k;
        return Container(
          padding: EdgeInsets.all(widget.borderWidth),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: widget.color, width: widget.borderWidth),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: glow.clamp(0.0, 1.0)),
                blurRadius: (10 * t + 4) * k,
                spreadRadius: 1 * k,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _RotatingHaloFrame extends StatefulWidget {
  final List<Color> colors;
  final double borderWidth;
  final Widget child;
  final Duration duration;

  const _RotatingHaloFrame({
    required this.colors,
    required this.borderWidth,
    required this.child,
    this.duration = const Duration(seconds: 3),
  });

  @override
  State<_RotatingHaloFrame> createState() => _RotatingHaloFrameState();
}

class _RotatingHaloFrameState extends State<_RotatingHaloFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
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
      builder: (context, child) {
        return Container(
          padding: EdgeInsets.all(widget.borderWidth),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: widget.colors,
              transform: GradientRotation(_ctrl.value * 6.28318),
            ),
            boxShadow: [
              BoxShadow(
                color: widget.colors.first.withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// 至尊头像：旋转彩虹光晕 + 绕头像一周闪烁星点粒子
class _SparkleSupremeFrame extends StatefulWidget {
  final List<Color> colors;
  final double borderWidth;
  final Widget child;

  const _SparkleSupremeFrame({
    required this.colors,
    required this.borderWidth,
    required this.child,
  });

  @override
  State<_SparkleSupremeFrame> createState() => _SparkleSupremeFrameState();
}

class _SparkleSupremeFrameState extends State<_SparkleSupremeFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sparkle;
  static const _phases = [0.0, 0.17, 0.33, 0.5, 0.67, 0.83];

  @override
  void initState() {
    super.initState();
    _sparkle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _sparkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        _RotatingHaloFrame(
          colors: widget.colors,
          borderWidth: widget.borderWidth,
          child: widget.child,
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _sparkle,
              builder: (ctx, _) => CustomPaint(
                painter: _SparklePainter(
                  progress: _sparkle.value,
                  phases: _phases,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SparklePainter extends CustomPainter {
  final double progress;
  final List<double> phases;

  static const _sparkleColors = <Color>[
    Color(0xFFFF4081),
    Color(0xFFFFEB3B),
    Color(0xFF40C4FF),
    Color(0xFFE040FB),
    Color(0xFFFFFFFF),
    Color(0xFFFF9800),
  ];

  _SparklePainter({required this.progress, required this.phases});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseR = math.min(size.width, size.height) / 2;
    for (int i = 0; i < phases.length; i++) {
      final localT = (progress + phases[i]) % 1.0;
      final opacity = math.sin(localT * math.pi).clamp(0.0, 1.0);
      if (opacity < 0.02) continue;
      // 角度随 progress 整体缓慢逆旋
      final angle =
          (i / phases.length) * 2 * math.pi - progress * math.pi * 0.6;
      // 粒子径向位置：靠近 halo 外边沿、略微起伏
      final r = baseR * (1.02 + 0.06 * math.sin(localT * math.pi * 2));
      final pos = center + Offset(math.cos(angle), math.sin(angle)) * r;
      // 柔光圈
      canvas.drawCircle(
        pos,
        3.2,
        Paint()
          ..color = _sparkleColors[i % _sparkleColors.length]
              .withValues(alpha: opacity * 0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );
      // 高亮核心
      canvas.drawCircle(
        pos,
        1.4,
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) =>
      old.progress != progress;
}

/// VIP 昵称样式（根据 name_effect_key 生成 TextStyle）
/// 不带动画的样式（gray/gold/gradient/glow）返回 Text 即可
/// 彩虹动画需用 VipNicknameAnimated
class VipNickname extends StatelessWidget {
  final VipBadgeModel? vip;
  final String text;
  final TextStyle? baseStyle;
  final int? maxLines;
  final TextOverflow overflow;

  const VipNickname({
    super.key,
    required this.vip,
    required this.text,
    this.baseStyle,
    this.maxLines,
    this.overflow = TextOverflow.ellipsis,
  });

  @override
  Widget build(BuildContext context) {
    final effect = vip?.nameEffectKey ?? 'none';
    final base = baseStyle ?? const TextStyle();

    if (vip == null || effect == 'none') {
      return Text(text, style: base, maxLines: maxLines, overflow: overflow);
    }

    switch (effect) {
      case 'gray_text':
        return Text(
          text,
          style: base.copyWith(color: const Color(0xFF757575)),
          maxLines: maxLines,
          overflow: overflow,
        );
      case 'gold_text':
        // 黄金：金色流光扫过（亮色高光在金色底上左右移动）
        return _ShimmerText(
          text: text,
          baseStyle: base.copyWith(fontWeight: FontWeight.w700),
          colors: const [
            Color(0xFFFFB300),
            Color(0xFFFFF59D),
            Color(0xFFFFB300),
          ],
          duration: const Duration(milliseconds: 2000),
          maxLines: maxLines,
          overflow: overflow,
        );
      case 'gradient_text':
        // 铂金：紫蓝黄渐变在文字上持续流动
        return _ShimmerText(
          text: text,
          baseStyle: base.copyWith(fontWeight: FontWeight.w600),
          colors: const [
            Color(0xFFE040FB),
            Color(0xFF40C4FF),
            Color(0xFFFFF59D),
            Color(0xFFE040FB),
          ],
          duration: const Duration(milliseconds: 3000),
          maxLines: maxLines,
          overflow: overflow,
        );
      case 'glow_text':
        return Text(
          text,
          style: base.copyWith(
            color: const Color(0xFF00E5FF),
            fontWeight: FontWeight.w700,
            shadows: const [
              Shadow(color: Color(0xFF00E5FF), blurRadius: 6),
              Shadow(color: Color(0xFF00E5FF), blurRadius: 2),
            ],
          ),
          maxLines: maxLines,
          overflow: overflow,
        );
      case 'rainbow_anim':
        // 至尊：彩虹流光 + 叠加闪烁星点
        return _RainbowAnimatedText(
          text: text,
          baseStyle: base,
          maxLines: maxLines,
          overflow: overflow,
          sparkle: true,
        );
      default:
        return Text(text, style: base, maxLines: maxLines, overflow: overflow);
    }
  }

}

/// 通用渐变流光文字：颜色带在文字上左右循环流动
class _ShimmerText extends StatefulWidget {
  final String text;
  final TextStyle baseStyle;
  final List<Color> colors;
  final Duration duration;
  final int? maxLines;
  final TextOverflow overflow;

  const _ShimmerText({
    required this.text,
    required this.baseStyle,
    required this.colors,
    required this.duration,
    this.maxLines,
    this.overflow = TextOverflow.ellipsis,
  });

  @override
  State<_ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<_ShimmerText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..repeat();
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
      builder: (_, __) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            final dx = _ctrl.value * bounds.width * 2;
            return LinearGradient(
              colors: widget.colors,
              begin: Alignment(-1 + 2 * _ctrl.value, 0),
              end: Alignment(1 + 2 * _ctrl.value, 0),
              tileMode: TileMode.mirror,
            ).createShader(
              Rect.fromLTWH(
                  dx - bounds.width, 0, bounds.width * 2, bounds.height),
            );
          },
          child: Text(
            widget.text,
            style: widget.baseStyle.copyWith(color: Colors.white),
            maxLines: widget.maxLines,
            overflow: widget.overflow,
          ),
        );
      },
    );
  }
}

class _RainbowAnimatedText extends StatefulWidget {
  final String text;
  final TextStyle baseStyle;
  final int? maxLines;
  final TextOverflow overflow;
  /// 是否在彩虹文字上叠加闪烁星点层
  final bool sparkle;

  const _RainbowAnimatedText({
    required this.text,
    required this.baseStyle,
    this.maxLines,
    this.overflow = TextOverflow.ellipsis,
    this.sparkle = false,
  });

  @override
  State<_RainbowAnimatedText> createState() => _RainbowAnimatedTextState();
}

class _RainbowAnimatedTextState extends State<_RainbowAnimatedText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  static const _rainbow = [
    Color(0xFFFF4081), Color(0xFFFF9800), Color(0xFFFFEB3B),
    Color(0xFF4CAF50), Color(0xFF40C4FF), Color(0xFFAA00FF),
    Color(0xFFFF4081),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rainbow = AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            final dx = _ctrl.value * bounds.width * 2;
            return LinearGradient(
              colors: _rainbow,
              begin: Alignment(-1 + 2 * _ctrl.value, 0),
              end: Alignment(1 + 2 * _ctrl.value, 0),
              tileMode: TileMode.mirror,
            ).createShader(
              Rect.fromLTWH(dx - bounds.width, 0, bounds.width * 2, bounds.height),
            );
          },
          child: Text(
            widget.text,
            style: widget.baseStyle.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            maxLines: widget.maxLines,
            overflow: widget.overflow,
          ),
        );
      },
    );

    if (!widget.sparkle) return rainbow;

    // 叠加闪烁星点层（十字光 + 高亮核心）
    return Stack(
      clipBehavior: Clip.none,
      children: [
        rainbow,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => CustomPaint(
                painter: _TextSparklePainter(_ctrl.value),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TextSparklePainter extends CustomPainter {
  final double t;
  _TextSparklePainter(this.t);

  // (xPct, yPct, phase, size)
  static const _specs = [
    [0.15, 0.25, 0.0, 2.8],
    [0.45, 0.75, 0.22, 2.3],
    [0.7, 0.2, 0.45, 3.2],
    [0.88, 0.65, 0.68, 2.4],
    [0.3, 0.85, 0.88, 2.0],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in _specs) {
      final localT = (t + s[2]) % 1.0;
      final opacity = math.sin(localT * math.pi).clamp(0.0, 1.0);
      if (opacity < 0.05) continue;
      final center = Offset(size.width * s[0], size.height * s[1]);
      final len = s[3];
      final strokePaint = Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..strokeWidth = 1.0
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
          center + Offset(-len, 0), center + Offset(len, 0), strokePaint);
      canvas.drawLine(
          center + Offset(0, -len), center + Offset(0, len), strokePaint);
      canvas.drawCircle(
        center,
        len * 0.35,
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TextSparklePainter old) => old.t != t;
}

/// VIP 等级小徽章（徽章 + 等级文字），可挂在昵称旁边
class VipLevelBadge extends StatelessWidget {
  final VipBadgeModel? vip;
  final double fontSize;

  const VipLevelBadge({
    super.key,
    required this.vip,
    this.fontSize = 10,
  });

  static const _bgColors = <String, Color>{
    'silver':   Color(0xFFB0B0B0),
    'gold':     Color(0xFFFFB300),
    'platinum': Color(0xFF80DEEA),
    'diamond':  Color(0xFF00E5FF),
    'supreme':  Color(0xFFE040FB),
  };

  @override
  Widget build(BuildContext context) {
    if (vip == null || vip!.isNormal) return const SizedBox.shrink();
    final bg = _bgColors[vip!.levelKey] ?? const Color(0xFFFFB300);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 0.5,
        vertical: fontSize * 0.1,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(fontSize * 0.6),
      ),
      child: Text(
        vip!.levelName,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}
