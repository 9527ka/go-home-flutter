import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/wallet_provider.dart';
import '../../config/currency.dart';
import '../../services/wallet_service.dart';
import '../../widgets/coin_icon.dart';

class DonateDialog extends StatefulWidget {
  final int postId;
  final String? postAuthor;

  const DonateDialog({super.key, required this.postId, this.postAuthor});

  @override
  State<DonateDialog> createState() => _DonateDialogState();
}

class _DonateDialogState extends State<DonateDialog> {
  final _msgController = TextEditingController();
  final _customController = TextEditingController();
  final _walletService = WalletService();
  double _selectedAmount = 0;
  bool _isAnonymous = false;
  bool _isSubmitting = false;
  bool _isCustom = false;

  static const _presetAmounts = [100.0, 500.0, 1000.0, 2000.0];

  @override
  void dispose() {
    _msgController.dispose();
    _customController.dispose();
    super.dispose();
  }

  double get _amount {
    if (_isCustom) return double.tryParse(_customController.text.trim()) ?? 0;
    return _selectedAmount;
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context)!;
    if (_amount <= 0) {
      Fluttertoast.showToast(msg: l.get('please_select_amount'));
      return;
    }
    final balance = context.read<WalletProvider>().balance;
    if (_amount > balance) {
      Fluttertoast.showToast(msg: l.get('insufficient_balance'));
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSubmitting = true);
    try {
      final res = await _walletService.donate(
        postId: widget.postId,
        amount: _amount,
        message: _msgController.text.trim(),
        isAnonymous: _isAnonymous,
      );
      if (mounted) {
        if (res['code'] == 0) {
          context.read<WalletProvider>().refresh();
          Navigator.pop(context, true);
          messenger.showSnackBar(
            SnackBar(content: Text(l.get('donate_success')), backgroundColor: AppTheme.successColor),
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
    final walletProvider = context.watch<WalletProvider>();

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
                const Icon(Icons.favorite, color: AppTheme.dangerColor, size: 22),
                const SizedBox(width: 8),
                Text(l.get('donate'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ],
            ),
            if (widget.postAuthor != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${l.get("donate_to")} ${widget.postAuthor}',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ),

            const SizedBox(height: 16),

            // 爱心值
            Row(children: [
              Text('${l.get("available_balance")}: ', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              CoinAmount(
                amount: walletProvider.balance,
                iconSize: 12,
                textStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ]),

            const SizedBox(height: 12),

            // 预设数量
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._presetAmounts.map((a) => ChoiceChip(
                  label: Text(CurrencyConfig.format(a)),
                  selected: !_isCustom && _selectedAmount == a,
                  onSelected: (v) {
                    if (v) setState(() {
                      _selectedAmount = a;
                      _isCustom = false;
                    });
                  },
                  selectedColor: AppTheme.primaryLight,
                )),
                ChoiceChip(
                  label: Text(l.get('custom')),
                  selected: _isCustom,
                  onSelected: (v) => setState(() => _isCustom = v),
                  selectedColor: AppTheme.primaryLight,
                ),
              ],
            ),

            // 自定义数量输入
            if (_isCustom) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                decoration: InputDecoration(
                  hintText: l.get('enter_amount'),
                  prefixText: '${CurrencyConfig.coinSymbol} ',
                  isDense: true,
                ),
              ),
            ],

            const SizedBox(height: 12),

            // 留言
            TextField(
              controller: _msgController,
              maxLength: 100,
              decoration: InputDecoration(
                hintText: '${l.get("leave_message")} (${l.get("optional")})',
                isDense: true,
              ),
            ),

            // 匿名开关
            Row(
              children: [
                Checkbox(
                  value: _isAnonymous,
                  onChanged: (v) => setState(() => _isAnonymous = v ?? false),
                  activeColor: AppTheme.primaryColor,
                ),
                Text(l.get('anonymous_donate'), style: const TextStyle(fontSize: 14)),
              ],
            ),

            const SizedBox(height: 12),

            // 确认按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_amount > 0 ? '${l.get("confirm_donate")} ${CurrencyConfig.format(_amount)}' : l.get('confirm_donate')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
