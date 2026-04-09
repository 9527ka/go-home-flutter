import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// Double-tap floating heart animation widget.
class HeartAnimation extends StatefulWidget {
  final VoidCallback onComplete;

  const HeartAnimation({super.key, required this.onComplete});

  Widget get widget => this;

  @override
  State<HeartAnimation> createState() => _HeartAnimationState();
}

class _HeartAnimationState extends State<HeartAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _positionAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 800), vsync: this);
    _scaleAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
    ]).animate(_controller);
    _opacityAnimation = Tween(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1.0)),
    );
    _positionAnimation = Tween(begin: 0.0, end: -80.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.3, 1.0, curve: Curves.easeOut)),
    );
    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: MediaQuery.of(context).size.width / 2 - 30,
      top: 200,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => Transform.translate(
          offset: Offset(0, _positionAnimation.value),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: const Icon(Icons.favorite, color: AppTheme.dangerColor, size: 60),
            ),
          ),
        ),
      ),
    );
  }
}
