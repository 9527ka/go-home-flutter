import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/lottery.dart';

/// 抽奖转盘：外环灯珠（交替闪烁）+ 扇形 + 奖品图标 + 立体指针
class LotteryWheel extends StatefulWidget {
  final List<LotteryPrizeModel> prizes;
  final double rotation;
  final double size;
  final Widget? centerChild;
  /// 是否处于旋转中（用于中心 GO 按钮脉冲开关，由外部控制）
  final bool spinning;

  const LotteryWheel({
    super.key,
    required this.prizes,
    this.rotation = 0,
    this.size = 300,
    this.centerChild,
    this.spinning = false,
  });

  /// 计算"将该扇形中心对齐顶部指针"所需的终态 rotation
  static double computeTargetRotation({
    required double currentRotation,
    required int prizeIndex,
    required int prizeCount,
    int extraTurns = 6,
  }) {
    final seg = 2 * math.pi / prizeCount;
    double targetMod = (-prizeIndex * seg) % (2 * math.pi);
    if (targetMod < 0) targetMod += 2 * math.pi;
    double currentMod = currentRotation % (2 * math.pi);
    if (currentMod < 0) currentMod += 2 * math.pi;
    double delta = targetMod - currentMod;
    if (delta <= 0) delta += 2 * math.pi;
    delta += extraTurns * 2 * math.pi;
    return currentRotation + delta;
  }

  @override
  State<LotteryWheel> createState() => _LotteryWheelState();
}

class _LotteryWheelState extends State<LotteryWheel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bulbCtrl;

  @override
  void initState() {
    super.initState();
    _bulbCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
  }

  @override
  void dispose() {
    _bulbCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 最底层：光晕（转盘周围的软发光）
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF4081).withValues(alpha: 0.35),
                  blurRadius: 40,
                  spreadRadius: 6,
                ),
                BoxShadow(
                  color: const Color(0xFFAA00FF).withValues(alpha: 0.25),
                  blurRadius: 60,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          // 外圈金色装饰环（不随转盘旋转，灯珠闪烁）
          AnimatedBuilder(
            animation: _bulbCtrl,
            builder: (_, __) => CustomPaint(
              size: Size.square(size),
              painter: _BulbRingPainter(progress: _bulbCtrl.value),
            ),
          ),
          // 旋转的扇形层（稍小一圈，留出外环灯珠位置）
          Transform.rotate(
            angle: widget.rotation,
            child: CustomPaint(
              size: Size.square(size * 0.86),
              painter: _WheelPainter(prizes: widget.prizes),
            ),
          ),
          // 中心 GO 按钮脉冲光（旋转中暂停以免干扰）
          if (!widget.spinning)
            AnimatedBuilder(
              animation: _bulbCtrl,
              builder: (_, __) {
                final t = (math.sin(_bulbCtrl.value * 2 * math.pi) + 1) / 2;
                return Container(
                  width: 92 + 10 * t,
                  height: 92 + 10 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFD54F)
                            .withValues(alpha: 0.3 + 0.4 * t),
                        blurRadius: 16 + 10 * t,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                );
              },
            ),
          // 中心按钮
          if (widget.centerChild != null) widget.centerChild!,
          // 顶部立体指针（向下扎入盘面）
          Positioned(
            top: -14,
            child: SizedBox(
              width: 58,
              height: 82,
              child: CustomPaint(painter: _PointerPainter()),
            ),
          ),
        ],
      ),
    );
  }
}

/// 外环金色灯珠：16 个灯珠交替亮灭 + 金色厚环
class _BulbRingPainter extends CustomPainter {
  final double progress;
  _BulbRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.shortestSide / 2;
    // 外环背景：金→深金径向
    canvas.drawCircle(
      center,
      outerR - 2,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFE082), Color(0xFFFF8F00)],
          stops: [0.6, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: outerR)),
    );
    // 内侧暗色环（和扇形分层）
    canvas.drawCircle(
      center,
      outerR * 0.86,
      Paint()..color = const Color(0xFF3E1F5E),
    );
    // 白色分割线
    canvas.drawCircle(
      center,
      outerR * 0.86 + 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );

    // 灯珠：沿外环均匀排布，按 progress 交替亮
    const bulbCount = 16;
    final bulbR = outerR - (outerR * 0.92) / 2;
    final bulbRingR = (outerR + outerR * 0.92) / 2;
    for (int i = 0; i < bulbCount; i++) {
      final angle = (i / bulbCount) * 2 * math.pi - math.pi / 2;
      final pos =
          center + Offset(math.cos(angle), math.sin(angle)) * bulbRingR;
      // 偶数/奇数错相位
      final phase = (progress + (i % 2) * 0.5) % 1.0;
      // 平滑闪烁
      final brightness = 0.3 + 0.7 * (math.sin(phase * 2 * math.pi) + 1) / 2;
      final color = i % 2 == 0
          ? const Color(0xFFFFF59D)
          : const Color(0xFFFF5252);
      // 外发光
      canvas.drawCircle(
        pos,
        bulbR * 1.2,
        Paint()
          ..color = color.withValues(alpha: brightness * 0.55)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * brightness),
      );
      // 灯珠主体
      canvas.drawCircle(
        pos,
        bulbR * 0.5,
        Paint()..color = color.withValues(alpha: 0.85),
      );
      // 高亮核心
      canvas.drawCircle(
        pos,
        bulbR * 0.2,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BulbRingPainter old) =>
      old.progress != progress;
}

/// 扇形 + 奖品图标 + 文字
///
/// 美化要点：
/// 1. 奇偶扇形交替红/金配色（经典大转盘观感），头奖扇形替换为紫→粉渐变并加金色高光
/// 2. 内环金色装饰盘（金圆环 + 描边 + 圆点纹），中心挖空给 GO 按钮让位
/// 3. 扇形顶部径向高光营造立体/陶瓷质感
/// 4. 文字：黑色描边 + 阴影，避免在亮金底色上糊成一团
class _WheelPainter extends CustomPainter {
  final List<LotteryPrizeModel> prizes;
  _WheelPainter({required this.prizes});

  // 经典大转盘配色：奇偶扇形交替（深红 / 明金），rarity≥3 扇形替换为紫粉
  // 返回 [内侧亮色, 外侧深色]
  List<Color> _sectorColors(int rarity, {required bool alt}) {
    if (rarity >= 3) {
      // 头奖：紫粉渐变
      return alt
          ? const [Color(0xFFFFB3D9), Color(0xFFC2185B)]
          : const [Color(0xFFE1BEE7), Color(0xFF6A1B9A)];
    }
    // 交替：alt=红系 / 非alt=金系
    return alt
        ? const [Color(0xFFEF5350), Color(0xFFB71C1C)]
        : const [Color(0xFFFFECB3), Color(0xFFFF8F00)];
  }

  // 文字在金底 / 红底都要清楚 → 黑描边 + 白字
  Color _textColor(int rarity, {required bool alt}) =>
      Colors.white;

  @override
  void paint(Canvas canvas, Size size) {
    final n = prizes.length;
    if (n == 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2 - 4;
    final seg = 2 * math.pi / n;
    final startBase = -math.pi / 2 - seg / 2;
    final rect = Rect.fromCircle(center: center, radius: r);

    // 根据扇形数量自适应字体/图标尺寸
    final double iconFontSize = n >= 12 ? 20 : (n >= 10 ? 22 : 24);
    final double textFontSize = n >= 12 ? 10.5 : (n >= 10 ? 11.5 : 13);
    // 文字位置的径向系数（sectors 多时向外挪，腾出中间图标空间）
    final double textRadial = n >= 10 ? 0.44 : 0.42;
    final double iconRadial = n >= 10 ? 0.74 : 0.72;
    // 文字最大宽度：取扇形在文本径向处的可用弧长 × 0.92（留 8% 边距）
    final double textMaxWidth =
        (seg * r * textRadial * 0.92).clamp(r * 0.2, r * 0.5);

    for (int i = 0; i < n; i++) {
      final prize = prizes[i];
      final colors = _sectorColors(prize.rarity, alt: i.isOdd);
      final startAngle = startBase + i * seg;

      // 1. 扇形填色（径向渐变：内侧亮、外侧深）
      final shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [colors[0], colors[1]],
      ).createShader(rect);
      canvas.drawArc(
        rect,
        startAngle,
        seg,
        true,
        Paint()..shader = shader,
      );

      // 2. 扇形顶部高光（陶瓷/珐琅质感）：从中心向扇形中线偏内 0.55R 处的白色径向光
      final midAngle = startAngle + seg / 2;
      final highlightCenter =
          center + Offset(math.cos(midAngle), math.sin(midAngle)) * r * 0.3;
      final highlightRect =
          Rect.fromCircle(center: highlightCenter, radius: r * 0.55);
      canvas.save();
      final clipPath = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(rect, startAngle, seg, false)
        ..close();
      canvas.clipPath(clipPath);
      canvas.drawRect(
        highlightRect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.35),
              Colors.white.withValues(alpha: 0.0),
            ],
          ).createShader(highlightRect),
      );
      canvas.restore();

      // 3. 分隔线：双色描边，金色内芯 + 深色外层，增强立体感
      final endAngle = startAngle + seg;
      final ep = center + Offset(math.cos(endAngle), math.sin(endAngle)) * r;
      canvas.drawLine(
        center,
        ep,
        Paint()
          ..color = const Color(0xFF5D1D1D).withValues(alpha: 0.5)
          ..strokeWidth = 3.0,
      );
      canvas.drawLine(
        center,
        ep,
        Paint()
          ..color = const Color(0xFFFFE082)
          ..strokeWidth = 1.4,
      );

      // 4. 奖品图标（靠外）
      final iconPos =
          center + Offset(math.cos(midAngle), math.sin(midAngle)) * r * iconRadial;
      canvas.save();
      canvas.translate(iconPos.dx, iconPos.dy);
      canvas.rotate(midAngle + math.pi / 2);
      final icon = prize.isThanks
          ? Icons.sentiment_neutral
          : (prize.rarity >= 3
              ? Icons.diamond
              : (prize.rarity >= 2
                  ? Icons.stars
                  : Icons.card_giftcard));
      // 图标底光圈
      canvas.drawCircle(
        Offset.zero,
        16,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      final iconPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: iconFontSize,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            color: Colors.white,
            shadows: const [
              Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      iconPainter.paint(
        canvas,
        Offset(-iconPainter.width / 2, -iconPainter.height / 2),
      );
      canvas.restore();

      // 5. 文字（更靠中心）：黑色描边 + 白字 + 阴影
      final textPos =
          center + Offset(math.cos(midAngle), math.sin(midAngle)) * r * textRadial;
      canvas.save();
      canvas.translate(textPos.dx, textPos.dy);
      canvas.rotate(midAngle + math.pi / 2);
      // 描边
      final strokePainter = TextPainter(
        text: TextSpan(
          text: prize.name,
          style: TextStyle(
            fontSize: textFontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = n >= 10 ? 2.4 : 3
              ..color = Colors.black.withValues(alpha: 0.85),
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: textMaxWidth);
      strokePainter.paint(
        canvas,
        Offset(-strokePainter.width / 2, -strokePainter.height / 2),
      );
      // 正文
      final tp = TextPainter(
        text: TextSpan(
          text: prize.name,
          style: TextStyle(
            color: _textColor(prize.rarity, alt: i.isOdd),
            fontSize: textFontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: textMaxWidth);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    // 6. 外圈金色粗边 + 内亮边
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFE57F), Color(0xFFFF8F00), Color(0xFFFFD54F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect),
    );
    canvas.drawCircle(
      center,
      r - 3.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.7),
    );
    // 外圈阴影（仅下方，增强立体）
    canvas.drawCircle(
      center + const Offset(0, 2),
      r + 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.black.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // 7. 内环金色装饰盘：半径 0.22R 的金色圆盘 + 圆点纹 + 描边
    final innerR = r * 0.22;
    // 金色盘底
    canvas.drawCircle(
      center,
      innerR,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFF8E1), Color(0xFFFFB300)],
          stops: [0.3, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: innerR)),
    );
    // 金色描边
    canvas.drawCircle(
      center,
      innerR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFFF6F00),
    );
    // 圆点纹（12 颗）
    const dotCount = 12;
    for (int i = 0; i < dotCount; i++) {
      final a = (i / dotCount) * 2 * math.pi;
      final p = center + Offset(math.cos(a), math.sin(a)) * (innerR - 5);
      canvas.drawCircle(
        p,
        1.8,
        Paint()..color = const Color(0xFFB71C1C),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) => old.prizes != prizes;
}

/// 顶部立体指针：盾形/水滴身 + 金边 + 红宝石渐变 + 顶部金色宝石圆帽 + 高光 + 阴影
class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // 几何基准
    const gemCy = 12.0; // 顶部宝石圆心 y
    const gemR = 10.0; // 顶部宝石半径
    const bodyTopY = gemCy + gemR * 0.6; // 身体顶部（与宝石有少量重叠）
    const bodyLeftX = 3.0;
    final bodyRightX = w - 3.0;
    const bodyShoulderY = gemCy + gemR + 8; // 肩部（身体最宽）
    final tipY = h - 2.0;

    // 1. 阴影（整体偏移下方，模糊）
    final shadowPath = Path()
      ..moveTo(cx, tipY + 2)
      ..quadraticBezierTo(
          bodyLeftX - 1, bodyShoulderY + 3, bodyLeftX - 1, bodyTopY + 2)
      ..quadraticBezierTo(cx, bodyTopY - 2, bodyRightX + 1, bodyTopY + 2)
      ..quadraticBezierTo(
          bodyRightX + 1, bodyShoulderY + 3, cx, tipY + 2)
      ..close();
    canvas.drawPath(
      shadowPath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // 2. 身体（水滴形：肩宽底尖，顶部与圆宝石相接）
    final bodyPath = Path()
      ..moveTo(cx, tipY)
      ..quadraticBezierTo(
          bodyLeftX, bodyShoulderY, bodyLeftX, bodyTopY)
      ..quadraticBezierTo(cx, bodyTopY - 4, bodyRightX, bodyTopY)
      ..quadraticBezierTo(bodyRightX, bodyShoulderY, cx, tipY)
      ..close();

    // 身体填色：红宝石 立体渐变
    canvas.drawPath(
      bodyPath,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            Color(0xFFFF7043),
            Color(0xFFE53935),
            Color(0xFF8B0000),
          ],
          stops: [0.0, 0.45, 1.0],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // 身体高光（左上 → 中部）
    final hiPath = Path()
      ..moveTo(cx - 2, tipY - 8)
      ..quadraticBezierTo(
          bodyLeftX + 6, bodyShoulderY, bodyLeftX + 4, bodyTopY + 2)
      ..quadraticBezierTo(cx - 4, bodyTopY + 1, cx - 1, bodyTopY + 10)
      ..quadraticBezierTo(cx - 6, bodyShoulderY, cx - 2, tipY - 8)
      ..close();
    canvas.drawPath(
      hiPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );

    // 身体金色粗描边 + 深红内描边（双层立体）
    canvas.drawPath(
      bodyPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..shader = const LinearGradient(
          colors: [
            Color(0xFFFFE082),
            Color(0xFFFF8F00),
            Color(0xFFFFD54F),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    canvas.drawPath(
      bodyPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = const Color(0xFF5D0000),
    );

    // 3. 顶部宝石圆帽：金色外环 + 红宝石心 + 白色闪点
    // 金色外环背景
    canvas.drawCircle(
      Offset(cx, gemCy),
      gemR + 1,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFF59D), Color(0xFFFF8F00)],
          stops: [0.4, 1.0],
        ).createShader(
            Rect.fromCircle(center: Offset(cx, gemCy), radius: gemR + 1)),
    );
    // 金色环描边
    canvas.drawCircle(
      Offset(cx, gemCy),
      gemR + 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0xFFFF6F00),
    );
    // 红宝石心
    canvas.drawCircle(
      Offset(cx, gemCy),
      gemR - 2.5,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.3),
          colors: [Color(0xFFFF8A80), Color(0xFFB71C1C)],
          stops: [0.0, 1.0],
        ).createShader(Rect.fromCircle(
            center: Offset(cx, gemCy), radius: gemR - 2.5)),
    );
    // 白色高光闪点
    canvas.drawCircle(
      Offset(cx - 2.5, gemCy - 2.5),
      2,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      Offset(cx + 3, gemCy + 2),
      1,
      Paint()..color = Colors.white.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(covariant _PointerPainter oldDelegate) => false;
}
