import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 暴击特效：红色爆闪 + "暴击 ×N！" 文字弹出
///
/// 结构：两层叠加
///   1. 红色径向爆闪（fade in 急速 → fade out 渐慢）
///   2. 暴击文字（弹性缩放出现 + 轻微抖动 + 延时淡出）
///
/// 独立 widget，使用时套在 Stack 顶层。播完自动回调 [onComplete]。
class CriticalFlashOverlay extends StatefulWidget {
  /// 倍数值（显示为 "暴击 ×5！"）
  final int multiplier;

  /// 完成回调
  final VoidCallback? onComplete;

  /// 文字颜色
  final Color textColor;

  /// 爆闪颜色
  final Color flashColor;

  const CriticalFlashOverlay({
    super.key,
    required this.multiplier,
    this.onComplete,
    this.textColor = Colors.white,
    this.flashColor = const Color(0xFFE74C3C),
  });

  @override
  State<CriticalFlashOverlay> createState() => _CriticalFlashOverlayState();
}

class _CriticalFlashOverlayState extends State<CriticalFlashOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _ctrl.forward().then((_) => widget.onComplete?.call());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          final t = _ctrl.value;

          // 红闪透明度：0~0.15 急速 fade in 到 0.55，0.15~0.5 fade out
          double flashOpacity;
          if (t < 0.15) {
            flashOpacity = (t / 0.15) * 0.55;
          } else if (t < 0.5) {
            flashOpacity = 0.55 * (1 - (t - 0.15) / 0.35);
          } else {
            flashOpacity = 0;
          }

          // 文字缩放：0.1~0.35 弹出，0.35~0.75 保持，0.75~1 淡出
          double scale;
          double textOpacity;
          if (t < 0.1) {
            scale = 0;
            textOpacity = 0;
          } else if (t < 0.35) {
            scale = Curves.elasticOut.transform((t - 0.1) / 0.25);
            textOpacity = ((t - 0.1) / 0.25).clamp(0.0, 1.0);
          } else if (t < 0.75) {
            // 轻微抖动（高频小振幅）
            final jitter = math.sin(t * math.pi * 18) * 0.03;
            scale = 1.0 + jitter;
            textOpacity = 1.0;
          } else {
            scale = 1.0;
            textOpacity = (1 - (t - 0.75) / 0.25).clamp(0.0, 1.0);
          }

          return Stack(
            alignment: Alignment.center,
            children: [
              // 红色径向爆闪
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: flashOpacity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            widget.flashColor.withOpacity(0.9),
                            widget.flashColor.withOpacity(0.0),
                          ],
                          stops: const [0.0, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // 暴击文字
              Opacity(
                opacity: textOpacity,
                child: Transform.scale(
                  scale: scale,
                  child: _buildCriticalText(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCriticalText() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF3B30), Color(0xFFFF9500)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: widget.flashColor.withOpacity(0.5),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Text(
        '暴击 ×${widget.multiplier}！',
        style: TextStyle(
          color: widget.textColor,
          fontSize: 32,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
          shadows: const [
            Shadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
      ),
    );
  }
}
