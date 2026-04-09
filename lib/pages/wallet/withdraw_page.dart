import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/wallet_provider.dart';
import '../../services/wallet_service.dart';
import '../../config/currency.dart';
import '../../models/withdrawal_order.dart';

class WithdrawPage extends StatefulWidget {
  const WithdrawPage({super.key});

  @override
  State<WithdrawPage> createState() => _WithdrawPageState();
}

class _WithdrawPageState extends State<WithdrawPage> {
  final _amountController = TextEditingController();
  final _addressController = TextEditingController();
  final _walletService = WalletService();
  String _chainType = 'TRC20';
  bool _isSubmitting = false;

  List<WithdrawalOrderModel> _orders = [];
  bool _loadingOrders = false;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _loadingOrders = true);
    try {
      final data = await _walletService.getWithdrawList();
      if (mounted) setState(() => _orders = data.list);
    } catch (e) { debugPrint('[WithdrawPage] load orders error: $e'); }
    if (mounted) setState(() => _loadingOrders = false);
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context)!;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final address = _addressController.text.trim();

    if (amount <= 0) {
      _showSnack(l.get('please_enter_amount'));
      return;
    }
    if (address.isEmpty) {
      _showSnack(l.get('please_enter_address'));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final res = await _walletService.withdraw(
        amount: amount,
        walletAddress: address,
        chainType: _chainType,
      );
      if (mounted) {
        if (res['code'] == 0) {
          _showSnack(l.get('withdraw_submitted'), success: true);
          _amountController.clear();
          _addressController.clear();
          _loadOrders();
          context.read<WalletProvider>().refresh();
        } else {
          _showSnack(res['msg'] ?? l.get('operation_failed'));
        }
      }
    } catch (e) {
      if (mounted) _showSnack(l.get('network_error'));
    }
    if (mounted) setState(() => _isSubmitting = false);
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppTheme.successColor : AppTheme.dangerColor,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final walletProvider = context.watch<WalletProvider>();
    final info = walletProvider.walletInfo;
    final feeRate = info?.withdrawalFeeRate ?? 0;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final fee = amount * feeRate;
    final netAmount = amount - fee;

    return Scaffold(
      appBar: AppBar(title: Text(l.get('withdraw'))),
      backgroundColor: AppTheme.scaffoldBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 爱心值提示
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet, color: AppTheme.primaryColor),
                  const SizedBox(width: 10),
                  Text(
                    '${l.get("available_balance")}: ${CurrencyConfig.format(walletProvider.balance)}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppTheme.primaryDark),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 发放表单
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.get('withdraw_amount'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: '${l.get("min_amount")}: ${CurrencyConfig.formatNumber(info?.minWithdrawal ?? 2000)} ${CurrencyConfig.coinUnit}',
                      prefixText: '${CurrencyConfig.coinSymbol} ',
                    ),
                  ),

                  if (amount > 0) ...[
                    const SizedBox(height: 8),
                    if (feeRate > 0)
                      Text(
                        '${l.get("fee")}: ${CurrencyConfig.format(fee)} (${(feeRate * 100).toStringAsFixed(1)}%)',
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    Text(
                      '≈ ${CurrencyConfig.toUsdt(feeRate > 0 ? netAmount : amount).toStringAsFixed(2)} USDT',
                      style: const TextStyle(fontSize: 14, color: AppTheme.successColor, fontWeight: FontWeight.w600),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // 链类型选择
                  Text(l.get('chain_type'), style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _chainChip('TRC20'),
                      const SizedBox(width: 8),
                      _chainChip('ERC20'),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Text(l.get('wallet_address'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _addressController,
                    decoration: InputDecoration(hintText: l.get('enter_wallet_address')),
                  ),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(l.get('submit_withdraw')),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 发放记录
            Text(l.get('withdraw_history'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),

            if (_loadingOrders)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
            else if (_orders.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(l.get('no_records'), style: const TextStyle(color: AppTheme.textHint)),
                ),
              )
            else
              ..._orders.map((order) => _buildOrderItem(order, l)),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _chainChip(String chain) {
    final selected = _chainType == chain;
    return ChoiceChip(
      label: Text(chain),
      selected: selected,
      onSelected: (v) {
        if (v) setState(() => _chainType = chain);
      },
      selectedColor: AppTheme.primaryLight,
      labelStyle: TextStyle(
        color: selected ? AppTheme.primaryColor : AppTheme.textSecondary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildOrderItem(WithdrawalOrderModel order, AppLocalizations l) {
    Color statusColor;
    String statusText;
    if (order.isPending) {
      statusColor = AppTheme.warningColor;
      statusText = l.get('pending_review');
    } else if (order.isApproved) {
      statusColor = AppTheme.successColor;
      statusText = l.get('approved');
    } else if (order.isRejected) {
      statusColor = AppTheme.dangerColor;
      statusText = l.get('rejected');
    } else {
      statusColor = AppTheme.successColor;
      statusText = l.get('completed');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(CurrencyConfig.format(order.amount),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${order.chainType} · ${order.walletAddress.length > 20 ? '${order.walletAddress.substring(0, 8)}...${order.walletAddress.substring(order.walletAddress.length - 8)}' : order.walletAddress}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 2),
                Text(order.createdAt, style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(statusText, style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
