import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/wallet_provider.dart';
import '../../services/wallet_service.dart';
import '../../services/upload_service.dart';
import '../../models/recharge_order.dart';
import '../../config/currency.dart';
import '../../models/api_response.dart';

class RechargePage extends StatefulWidget {
  const RechargePage({super.key});

  @override
  State<RechargePage> createState() => _RechargePageState();
}

class _RechargePageState extends State<RechargePage> with SingleTickerProviderStateMixin {
  final _amountController = TextEditingController();
  final _txHashController = TextEditingController();
  final _walletService = WalletService();
  late TabController _tabController;
  bool _isSubmitting = false;
  String? _screenshotUrl;

  // 获取记录
  List<RechargeOrderModel> _orders = [];
  bool _loadingOrders = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOrders();
    // 确保爱心中心信息（含获取地址）已加载
    final provider = context.read<WalletProvider>();
    if (provider.walletInfo == null) {
      provider.loadWalletInfo();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _txHashController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _loadingOrders = true);
    try {
      final data = await _walletService.getRechargeList();
      if (mounted) setState(() => _orders = data.list);
    } catch (e) { debugPrint('[RechargePage] load orders error: $e'); }
    if (mounted) setState(() => _loadingOrders = false);
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context)!;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final txHash = _txHashController.text.trim();

    if (amount <= 0) {
      _showSnack(l.get('please_enter_amount'));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final res = await _walletService.recharge(
        amount: amount,
        txHash: txHash,
        screenshotUrl: _screenshotUrl,
      );
      if (mounted) {
        if (res['code'] == 0) {
          _showSnack(l.get('recharge_submitted'), success: true);
          _amountController.clear();
          _txHashController.clear();
          _screenshotUrl = null;
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

    return Scaffold(
      appBar: AppBar(title: Text(l.get('recharge'))),
      backgroundColor: AppTheme.scaffoldBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 汇率提示
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.swap_horiz, color: AppTheme.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '1 USDT = ${CurrencyConfig.ratePerUsdt.toInt()} ${CurrencyConfig.coinUnit}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primaryDark),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // USDT 收款地址（获取）
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
                  const Text('USDT 收款地址', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  TabBar(
                    controller: _tabController,
                    labelColor: AppTheme.primaryColor,
                    unselectedLabelColor: AppTheme.textSecondary,
                    indicatorColor: AppTheme.primaryColor,
                    tabs: const [
                      Tab(text: 'TRC20'),
                      Tab(text: 'ERC20'),
                    ],
                  ),
                  SizedBox(
                    height: 100,
                    child: walletProvider.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _buildAddressCard(info?.usdtAddressTrc20 ?? '', l),
                              _buildAddressCard(info?.usdtAddressErc20 ?? '', l),
                            ],
                          ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 获取表单
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
                  Text('${l.get('recharge_amount')} (USDT)', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                    decoration: InputDecoration(
                      hintText: '${l.get("min_amount")}: ${info?.minRecharge ?? 10} USDT',
                      prefixText: '\$ ',
                    ),
                  ),
                  Builder(builder: (_) {
                    final usdtAmount = double.tryParse(_amountController.text.trim()) ?? 0;
                    if (usdtAmount > 0) {
                      final coins = CurrencyConfig.fromUsdt(usdtAmount);
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '≈ ${CurrencyConfig.formatWithUnit(coins)}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.successColor),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                  const SizedBox(height: 12),
                  Text('TxHash (${l.get("optional")})', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _txHashController,
                    decoration: InputDecoration(hintText: l.get('enter_tx_hash')),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(l.get('submit_recharge')),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 获取记录
            Text(l.get('recharge_history'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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

  Widget _buildAddressCard(String address, AppLocalizations l) {
    if (address.isEmpty) {
      return Center(child: Text(l.get('address_not_configured'), style: const TextStyle(color: AppTheme.textHint)));
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              address,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18, color: AppTheme.primaryColor),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: address));
              _showSnack(l.get('copied'), success: true);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(RechargeOrderModel order, AppLocalizations l) {
    Color statusColor;
    String statusText;
    if (order.isPending) {
      statusColor = AppTheme.warningColor;
      statusText = l.get('pending_review');
    } else if (order.isApproved) {
      statusColor = AppTheme.successColor;
      statusText = l.get('approved');
    } else {
      statusColor = AppTheme.dangerColor;
      statusText = l.get('rejected');
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
                Text('${order.amount.toStringAsFixed(2)} USDT',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
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
