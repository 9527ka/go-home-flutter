import 'package:flutter/material.dart';
import '../config/currency.dart';
import '../config/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/sign_result.dart';

/// 签到成功奖励弹窗
class SignRewardDialog extends StatefulWidget {
  final SignResultModel result;

  const SignRewardDialog({super.key, required this.result});

  @override
  State<SignRewardDialog> createState() => _SignRewardDialogState();
}

class _SignRewardDialogState extends State<SignRewardDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final isBonus = result.isBonus;
    final l = AppLocalizations.of(context)!;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
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
                // 暴击标识
                if (isBonus) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B35), Color(0xFFFF9F1C)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${result.bonusRate}x ${l.get("bonus_critical")}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

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
                const SizedBox(height: 8),

                Text(
                  l.get('day_n').replaceAll('{n}', '${result.dayInCycle}'),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),

                // 奖励金额
                Text(
                  '+${CurrencyConfig.formatNumber(result.reward)} ${CurrencyConfig.coinUnit}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: isBonus ? AppTheme.accentColor : AppTheme.primaryColor,
                  ),
                ),

                // 暴击详情
                if (isBonus) ...[
                  const SizedBox(height: 4),
                  Text(
                    l.get('base_reward_multiply')
                        .replaceAll('{base}', CurrencyConfig.formatNumber(result.baseReward))
                        .replaceAll('{rate}', '${result.bonusRate}'),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // 提示文字
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
          ),
        ),
      ),
    );
  }
}
