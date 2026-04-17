import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import '../../config/currency.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/wallet_provider.dart';
import '../../services/wallet_service.dart';

class RedPacketSendDialog extends StatefulWidget {
  final int targetType; // 1=公共 2=私聊 3=群聊
  final int targetId;

  const RedPacketSendDialog({
    super.key,
    required this.targetType,
    required this.targetId,
  });

  @override
  State<RedPacketSendDialog> createState() => _RedPacketSendDialogState();
}

class _RedPacketSendDialogState extends State<RedPacketSendDialog> {
  final _amountController = TextEditingController();
  final _countController = TextEditingController(text: '1');
  final _greetingController = TextEditingController();
  final _walletService = WalletService();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _countController.dispose();
    _greetingController.dispose();
    super.dispose();
  }

  bool get _isPrivate => widget.targetType == 2;

  Future<void> _submit() async {
    final l = AppLocalizations.of(context)!;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final count = _isPrivate ? 1 : (int.tryParse(_countController.text.trim()) ?? 0);

    if (amount <= 0) {
      Fluttertoast.showToast(msg: l.get('please_enter_amount'));
      return;
    }
    if (!_isPrivate && count <= 0) {
      Fluttertoast.showToast(msg: l.get('please_enter_count'));
      return;
    }

    // 提前捕获父级 ScaffoldMessenger，关闭 Dialog 后仍可弹提示
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isSubmitting = true);
    try {
      final res = await _walletService.sendRedPacket(
        targetType: widget.targetType,
        targetId: widget.targetId,
        totalAmount: amount,
        totalCount: count,
        greeting: _greetingController.text.trim(),
      );
      if (mounted) {
        if (res['code'] == 0) {
          context.read<WalletProvider>().refresh();
          Navigator.pop(context, res['data']);
        } else {
          final errMsg = res['msg'] ?? l.get('operation_failed');
          Navigator.pop(context);
          messenger.showSnackBar(
            SnackBar(content: Text(errMsg), backgroundColor: AppTheme.dangerColor),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final errMsg = l.get('network_error');
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(content: Text(errMsg), backgroundColor: AppTheme.dangerColor),
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFD4534B), Color(0xFFBE4740)],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // 标题
            Text(
              l.get('send_red_packet'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
            ),

            const SizedBox(height: 20),

            // 总金额
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                filled: false,
                labelText: l.get('total_amount'),
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                floatingLabelStyle: TextStyle(color: Colors.white.withOpacity(0.9)),
                prefixText: '${CurrencyConfig.coinSymbol} ',
                prefixStyle: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
              ),
            ),

            const SizedBox(height: 16),

            // 红包个数（私聊固定1个，不显示）
            if (!_isPrivate) ...[
              TextField(
                controller: _countController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  filled: false,
                  labelText: l.get('red_packet_count'),
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                  floatingLabelStyle: TextStyle(color: Colors.white.withOpacity(0.9)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 祝福语
            TextField(
              controller: _greetingController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLength: 30,
              decoration: InputDecoration(
                filled: false,
                labelText: l.get('rp_greeting_label'),
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                floatingLabelStyle: TextStyle(color: Colors.white.withOpacity(0.9)),
                hintText: l.get('red_packet_greeting_hint'),
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                counterStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withOpacity(0.3))),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
              ),
            ),

            const SizedBox(height: 8),

            // 余额
            Text(
              '${l.get("available_balance")}: ${CurrencyConfig.format(walletProvider.balance)}',
              style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.7)),
            ),

            const SizedBox(height: 20),

            // 发送按钮
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD54F),
                  foregroundColor: const Color(0xFFBE4740),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l.get('send'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}
