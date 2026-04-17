import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 金币发散动画：多个金币从中心向四周放射 + 抛物线下落 + 淡出
/// 原地发散，不跟随目标位置。
///
/// 用法：作为 Stack 的一层覆盖在弹窗之上；动画自动播放，完成后回调 [onComplete]。
class CoinBurstAnimation extends StatefulWidget {
  /// 金币数量
  final int coinCount;

  /// 发散半径（像素）
  final double radius;

  /// 单个金币大小
  final double coinSize;

  /// 资源路径（gold.png）
  final String assetPath;

  /// 总时长
  final Duration duration;

  /// 完成回调
  final VoidCallback? onComplete;

  const CoinBurstAnimation({
    super.key,
    this.coinCount = 14,
    this.radius = 140,
    this.coinSize = 28,
    this.assetPath = 'assets/icon/gold.png',
    this.duration = const Duration(milliseconds: 1400),
    this.onComplete,
  });

  @override
  State<CoinBurstAnimation> createState() => _CoinBurstAnimationState();
}

class _CoinBurstAnimationState extends State<CoinBurstAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_CoinSpec> _coins;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: widget.duration, vsync: this);

    final rand = math.Random();
    _coins = List.generate(widget.coinCount, (i) {
      // 均匀发散 + 随机抖动
      final baseAngle = (i / widget.coinCount) * math.pi * 2;
      final angle = baseAngle + (rand.nextDouble() - 0.5) * 0.6;
      final distance = widget.radius * (0.5 + rand.nextDouble() * 0.5);
      final size = widget.coinSize * (0.7 + rand.nextDouble() * 0.6);
      final delay = rand.nextDouble() * 0.15; // 0~15% 延迟错开
      final spinDir = rand.nextBool() ? 1.0 : -1.0;
      final spinSpeed = 1.5 + rand.nextDouble() * 2.0;
      return _CoinSpec(
        angle: angle,
        distance: distance,
        size: size,
        delay: delay,
        spinDir: spinDir,
        spinSpeed: spinSpeed,
      );
    });

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
          return Stack(
            alignment: Alignment.center,
            children: _coins.map(_buildCoin).toList(),
          );
        },
      ),
    );
  }

  Widget _buildCoin(_CoinSpec spec) {
    final raw = _ctrl.value;
    // 带延迟的本地进度 0..1
    final t = ((raw - spec.delay) / (1 - spec.delay)).clamp(0.0, 1.0);

    // 放射距离：先快后慢（easeOut）
    final ease = Curves.easeOut.transform(t);
    final dx = math.cos(spec.angle) * spec.distance * ease;
    // 竖直方向加抛物线：前半段向上/外放，后半段受重力下坠
    final gravity = math.pow(t, 2).toDouble() * 60;
    final dy = math.sin(spec.angle) * spec.distance * ease + gravity;

    // 尺度：弹出 → 微缩
    final scale = t < 0.25
        ? Curves.elasticOut.transform(t / 0.25) * 1.05
        : 1.05 - (t - 0.25) * 0.15;

    // 透明度：后半段淡出
    final opacity = t < 0.7 ? 1.0 : (1.0 - (t - 0.7) / 0.3).clamp(0.0, 1.0);

    // 旋转
    final rotate = t * spec.spinSpeed * math.pi * spec.spinDir;

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Transform.rotate(
        angle: rotate,
        child: Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Image.asset(
              widget.assetPath,
              width: spec.size,
              height: spec.size,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
    );
  }
}

class _CoinSpec {
  final double angle;
  final double distance;
  final double size;
  final double delay;
  final double spinDir;
  final double spinSpeed;

  _CoinSpec({
    required this.angle,
    required this.distance,
    required this.size,
    required this.delay,
    required this.spinDir,
    required this.spinSpeed,
  });
}
