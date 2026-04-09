import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/app_config_provider.dart';
import '../../config/currency.dart';
import '../../services/wallet_service.dart';
import '../../widgets/coin_icon.dart';

class BoostDialog extends StatefulWidget {
  final int postId;

  const BoostDialog({super.key, required this.postId});

  @override
  State<BoostDialog> createState() => _BoostDialogState();
}

class _BoostDialogState extends State<BoostDialog> {
  final _walletService = WalletService();
  int _selectedHours = 1;
  bool _isSubmitting = false;

  static const _hourOptions = [1, 3, 6, 12, 24];

  Future<void> _submit() async {
    final l = AppLocalizations.of(context)!;
    final appConfig = context.read<AppConfigProvider>();
    final totalCost = appConfig.boostHourlyRate * _selectedHours;
    final balance = context.read<WalletProvider>().balance;
    if (totalCost > balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.get('insufficient_balance')), backgroundColor: AppTheme.dangerColor),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final res = await _walletService.boost(postId: widget.postId, hours: _selectedHours);
      if (mounted) {
        if (res['code'] == 0) {
          context.read<WalletProvider>().refresh();
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l.get('boost_success')), backgroundColor: AppTheme.successColor),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['msg'] ?? l.get('operation_failed')), backgroundColor: AppTheme.dangerColor),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.get('network_error')), backgroundColor: AppTheme.dangerColor),
        );
      }
    }
    if (mounted) setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final walletProvider = context.watch<WalletProvider>();
    final appConfig = context.watch<AppConfigProvider>();
    final hourlyRate = appConfig.boostHourlyRate;
    final totalCost = hourlyRate * _selectedHours;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                const Icon(Icons.rocket_launch, color: AppTheme.accentColor, size: 22),
                const SizedBox(width: 8),
                Text(l.get('boost_post'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ],
            ),

            const SizedBox(height: 8),
            Text(
              l.get('boost_description'),
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),

            const SizedBox(height: 16),

            // 时长选择
            Text(l.get('select_duration'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _hourOptions.map((h) => ChoiceChip(
                label: Text('${h}h'),
                selected: _selectedHours == h,
                onSelected: (v) {
                  if (v) setState(() => _selectedHours = h);
                },
                selectedColor: AppTheme.primaryLight,
              )).toList(),
            ),

            const SizedBox(height: 16),

            // 费用详情
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.scaffoldBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l.get('hourly_rate'), style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        CoinAmount(amount: hourlyRate, iconSize: 12, textStyle: const TextStyle(fontSize: 13)),
                        const Text('/h', style: TextStyle(fontSize: 13)),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l.get('duration'), style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      Text('$_selectedHours ${l.get("hours")}', style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l.get('total_cost'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      CoinAmount(
                        amount: totalCost,
                        iconSize: 16,
                        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.primaryColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
            Row(children: [
              Text('${l.get("available_balance")}: ', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              CoinAmount(
                amount: walletProvider.balance,
                iconSize: 12,
                textStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ]),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('${l.get("confirm_boost")} ${CurrencyConfig.format(totalCost)}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
