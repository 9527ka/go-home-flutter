import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../config/currency.dart';
import '../config/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/sign_result.dart';
import 'sign/coin_burst_animation.dart';
import 'sign/critical_flash_overlay.dart';

/// 签到成功奖励弹窗
///
/// 演出编排：
/// 1) 弹窗弹性入场（elastic scale + fade）
/// 2) 金币原地发散（按 bonusRate 分级数量/半径）
/// 3) 暴击 → 覆盖爆闪 + "暴击 ×N！" + 卡片震屏（按 rate 分级强度）
class SignRewardDialog extends StatefulWidget {
  final SignResultModel result;

  const SignRewardDialog({super.key, required this.result});

  @override
  State<SignRewardDialog> createState() => _SignRewardDialogState();
}

class _SignRewardDialogState extends State<SignRewardDialog>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  // 震屏控制器：按 bonusRate 分级强度，暴击启动时 forward 一次
  late AnimationController _shakeCtrl;

  /// 触发后才渲染，避免一入场就立刻爆
  bool _showCoinBurst = false;
  bool _showCritical = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.forward();

    _shakeCtrl = AnimationController(
      // 震屏时长随 rate 递增；非暴击不启动
      duration: _shakeDurationForRate(widget.result.bonusRate),
      vsync: this,
    );

    // 入场完成后启动金币发散；暴击时同步启动红闪 + 震屏
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _showCoinBurst = true;
        _showCritical = widget.result.isBonus;
      });
      if (widget.result.isBonus) {
        _shakeCtrl.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  /// 按 bonusRate 返回粒子数量
  int _coinCountForRate(int rate) {
    if (rate >= 20) return 40;
    if (rate >= 10) return 30;
    if (rate >= 5)  return 22;
    if (rate >= 2)  return 14;
    return 10;
  }

  /// 按 bonusRate 返回发散半径
  double _coinRadiusForRate(int rate) {
    if (rate >= 20) return 260;
    if (rate >= 10) return 220;
    if (rate >= 5)  return 180;
    if (rate >= 2)  return 140;
    return 120;
  }

  /// 按 bonusRate 返回金币尺寸
  double _coinSizeForRate(int rate) {
    if (rate >= 20) return 38;
    if (rate >= 10) return 34;
    if (rate >= 5)  return 30;
    if (rate >= 2)  return 26;
    return 24;
  }

  /// 按 bonusRate 返回震屏幅度（像素）
  double _shakeIntensityForRate(int rate) {
    if (rate >= 20) return 18;
    if (rate >= 10) return 12;
    if (rate >= 5)  return 8;
    if (rate >= 2)  return 4;
    return 0;
  }

  /// 按 bonusRate 返回震屏时长
  Duration _shakeDurationForRate(int rate) {
    if (rate >= 20) return const Duration(milliseconds: 900);
    if (rate >= 10) return const Duration(milliseconds: 700);
    if (rate >= 5)  return const Duration(milliseconds: 500);
    if (rate >= 2)  return const Duration(milliseconds: 350);
    return const Duration(milliseconds: 1); // 占位
  }

  /// 按 bonusRate 返回爆闪色
  Color _flashColorForRate(int rate) {
    if (rate >= 20) return const Color(0xFFAA00FF); // 紫（至尊暴击）
    if (rate >= 10) return const Color(0xFFFFB300); // 金
    if (rate >= 5)  return const Color(0xFFE74C3C); // 红
    if (rate >= 2)  return const Color(0xFFFF9500); // 橙
    return const Color(0xFFE74C3C);
  }

  /// 计算当前震屏偏移：渐弱正弦
  Offset _currentShakeOffset() {
    final rate = widget.result.bonusRate;
    final intensity = _shakeIntensityForRate(rate);
    if (intensity == 0) return Offset.zero;
    final t = _shakeCtrl.value;
    if (t <= 0 || t >= 1) return Offset.zero;
    final decay = 1 - t;
    // 高 rate 加一层垂直抖动
    final dx = math.sin(t * math.pi * 18) * intensity * decay;
    final dy = rate >= 10
        ? math.cos(t * math.pi * 22) * intensity * 0.6 * decay
        : 0.0;
    return Offset(dx, dy);
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final isBonus = result.isBonus;
    final l = AppLocalizations.of(context)!;
    final rate = result.bonusRate;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 主卡片（带震屏）
          AnimatedBuilder(
            animation: _shakeCtrl,
            builder: (_, child) {
              return Transform.translate(
                offset: _currentShakeOffset(),
                child: child,
              );
            },
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: _buildCard(result, isBonus, l),
              ),
            ),
          ),

          // 金币发散（按 rate 分级）
          if (_showCoinBurst)
            Positioned.fill(
              child: IgnorePointer(
                child: CoinBurstAnimation(
                  coinCount: _coinCountForRate(rate),
                  radius: _coinRadiusForRate(rate),
                  coinSize: _coinSizeForRate(rate),
                  onComplete: () {
                    if (mounted) setState(() => _showCoinBurst = false);
                  },
                ),
              ),
            ),

          // 暴击红闪 + 文字
          if (_showCritical)
            Positioned.fill(
              child: CriticalFlashOverlay(
                multiplier: rate,
                flashColor: _flashColorForRate(rate),
                onComplete: () {
                  if (mounted) setState(() => _showCritical = false);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(SignResultModel result, bool isBonus, AppLocalizations l) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部：基础 → 暴击后 + ×N 倍数标
          _buildRewardHeader(result, isBonus, l),
          const SizedBox(height: 16),

          // 签到成功图标
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isBonus
                  ? AppTheme.accentColor.withOpacity(0.1)
                  : AppTheme.successColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isBonus ? Icons.local_fire_department : Icons.check_circle,
              size: 36,
              color: isBonus ? AppTheme.accentColor : AppTheme.successColor,
            ),
          ),
          const SizedBox(height: 16),

          // 签到成功文字
          Text(
            l.get('sign_success'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),

          Text(
            l.get('day_n').replaceAll('{n}', '${result.dayInCycle}'),
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // 释放提示
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.scaffoldBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              l.get('reward_release_hint'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 关闭按钮
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                elevation: 0,
              ),
              child: Text(l.get('got_it')),
            ),
          ),
        ],
      ),
    );
  }

  /// 奖励数值头：基础值 → 暴击后值 + 倍率徽章
  Widget _buildRewardHeader(SignResultModel result, bool isBonus, AppLocalizations l) {
    final baseText = '+${CurrencyConfig.formatNumber(result.baseReward)}';
    final finalText = '+${CurrencyConfig.formatNumber(result.reward)}';

    if (!isBonus) {
      // 无暴击：仅显示最终奖励 + 单位
      return Column(
        children: [
          Text(
            '$finalText ${CurrencyConfig.coinUnit}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      );
    }

    // 暴击：上方显示 "基础 → 暴击后 × 倍率"
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 基础值（灰色、带删除线）
            Text(
              baseText,
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textHint,
                decoration: TextDecoration.lineThrough,
                decorationColor: AppTheme.textHint,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward, size: 16, color: AppTheme.textHint),
            const SizedBox(width: 6),
            // 暴击后值
            Text(
              finalText,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppTheme.dangerColor,
              ),
            ),
            const SizedBox(width: 6),
            // 倍率徽章
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B35), Color(0xFFFF9F1C)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '×${result.bonusRate}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // 爱心值单位 + 暴击标识
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              CurrencyConfig.coinUnit,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.local_fire_department,
                size: 14, color: AppTheme.dangerColor),
            const SizedBox(width: 2),
            Text(
              l.get('bonus_critical'),
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.dangerColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
