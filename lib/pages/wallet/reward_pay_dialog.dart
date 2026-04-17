import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/currency.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/wallet_provider.dart';
import '../../services/wallet_service.dart';
import '../../widgets/coin_icon.dart';

/// 发放悬赏弹窗
class RewardPayDialog extends StatefulWidget {
  final int postId;
  final int clueId;
  final String? clueUserName;
  final double maxAmount; // 剩余可发放金额

  const RewardPayDialog({
    super.key,
    required this.postId,
    required this.clueId,
    this.clueUserName,
    required this.maxAmount,
  });

  @override
  State<RewardPayDialog> createState() => _RewardPayDialogState();
}

class _RewardPayDialogState extends State<RewardPayDialog> {
  final _amountCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  final _walletService = WalletService();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  double get _amount => double.tryParse(_amountCtrl.text.trim()) ?? 0;

  Future<void> _submit() async {
    final l = AppLocalizations.of(context)!;
    if (_amount <= 0) {
      Fluttertoast.showToast(msg: l.get('please_enter_amount'));
      return;
    }
    if (_amount > widget.maxAmount) {
      Fluttertoast.showToast(msg: l.get('reward_exceed'));
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSubmitting = true);
    try {
      final res = await _walletService.rewardPay(
        postId: widget.postId,
        clueId: widget.clueId,
        amount: _amount,
        message: _msgCtrl.text.trim(),
      );
      if (mounted) {
        if (res['code'] == 0) {
          context.read<WalletProvider>().refresh();
          Navigator.pop(context, true);
          messenger.showSnackBar(
            SnackBar(content: Text(l.get('reward_pay_success')), backgroundColor: AppTheme.successColor),
          );
        } else {
          Navigator.pop(context);
          messenger.showSnackBar(
            SnackBar(content: Text(res['msg'] ?? l.get('operation_failed')), backgroundColor: AppTheme.dangerColor),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(content: Text(l.get('network_error')), backgroundColor: AppTheme.dangerColor),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.monetization_on, color: Color(0xFFFF8F00), size: 22),
                const SizedBox(width: 8),
                Text(l.get('reward_pay'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ],
            ),
            if (widget.clueUserName != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${l.get("reward_pay_to")} ${widget.clueUserName}',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ),
            const SizedBox(height: 12),
            // 剩余可发放
            Row(children: [
              Text('${l.get("reward_remaining")}: ', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              CoinAmount(
                amount: widget.maxAmount,
                iconSize: 12,
                textStyle: const TextStyle(fontSize: 13, color: Color(0xFFFF8F00), fontWeight: FontWeight.w600),
              ),
            ]),
            const SizedBox(height: 12),
            // 快捷按钮：全额发放
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: Text(l.get('reward_pay_all')),
                  onPressed: () {
                    _amountCtrl.text = CurrencyConfig.format(widget.maxAmount);
                  },
                ),
                if (widget.maxAmount >= 200)
                  ActionChip(
                    label: Text(CurrencyConfig.format(widget.maxAmount / 2)),
                    onPressed: () {
                      _amountCtrl.text = CurrencyConfig.format(widget.maxAmount / 2);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // 金额输入
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
              decoration: InputDecoration(
                hintText: l.get('enter_amount'),
                prefixText: '${CurrencyConfig.coinSymbol} ',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            // 留言
            TextField(
              controller: _msgCtrl,
              maxLength: 100,
              decoration: InputDecoration(
                hintText: '${l.get("leave_message")} (${l.get("optional")})',
                isDense: true,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l.get('reward_dispute_hint'),
              style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8F00),
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_amount > 0 ? '${l.get("reward_confirm_pay")} ${CurrencyConfig.format(_amount)}' : l.get('reward_confirm_pay')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
