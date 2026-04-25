import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/iap_products.dart';
import '../../config/currency.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/wallet_provider.dart';
import '../../services/iap_service.dart';
import '../../services/wallet_service.dart';
import '../../models/recharge_order.dart';
import '../../widgets/coin_icon.dart';

/// 是否使用 USDT 充值（web 和 android 使用 USDT，iOS 使用 IAP）
bool get _useUsdt => kIsWeb || defaultTargetPlatform == TargetPlatform.android;

class RechargePage extends StatefulWidget {
  const RechargePage({super.key});

  @override
  State<RechargePage> createState() => _RechargePageState();
}

class _RechargePageState extends State<RechargePage> {
  // IAP
  final _iap = IapService.instance;
  String? _selectedProductId;
  bool _purchasing = false;
  bool _iapLoading = false;
  String? _iapError;
  int _pendingReceiptCount = 0;

  // USDT
  final _walletService = WalletService();
  final _amountController = TextEditingController();
  final _txHashController = TextEditingController();
  bool _isSubmitting = false;

  List<RechargeOrderModel> _orders = [];
  bool _loadingOrders = false;

  @override
  void initState() {
    super.initState();
    if (!_useUsdt) {
      // 注册统一回调（不要在 _purchase 里二次包装，避免 onSuccess 链式累加造成
      // 多次 loadOrders / refresh / snack 闪现）
      _iap.onPurchaseSuccess = _handleIapSuccess;
      _iap.onPurchaseError = _handleIapError;
      _initIap();
    }
    _loadOrders();
    final provider = context.read<WalletProvider>();
    if (provider.walletInfo == null) {
      provider.loadWalletInfo();
    }
  }

  void _handleIapSuccess() {
    if (!mounted) return;
    if (_purchasing) setState(() => _purchasing = false);
    final l = AppLocalizations.of(context)!;
    _showSnack(l.get('purchase_success'), success: true);
    _loadOrders();
    context.read<WalletProvider>().refresh();
    _iap.pendingReceiptsCount().then((c) {
      if (mounted) setState(() => _pendingReceiptCount = c);
    });
  }

  void _handleIapError(String error) {
    if (!mounted) return;
    if (_purchasing) setState(() => _purchasing = false);
    final l = AppLocalizations.of(context)!;
    _showSnack('${l.get('purchase_failed')}: $error');
    _iap.pendingReceiptsCount().then((c) {
      if (mounted) setState(() => _pendingReceiptCount = c);
    });
  }

  Future<void> _initIap({bool force = false}) async {
    if (_iapLoading) return;
    if (mounted) {
      setState(() {
        _iapLoading = true;
        _iapError = null;
      });
    }
    try {
      if (force) {
        await _iap.forceReinitialize().timeout(const Duration(seconds: 15));
      } else {
        await _iap.ensureInitialized().timeout(const Duration(seconds: 15));
      }
      if (_iap.isAvailable && _iap.products.isEmpty) {
        await _iap.loadProducts();
      }
      _pendingReceiptCount = await _iap.pendingReceiptsCount();
      if (!_iap.isAvailable) {
        _iapError = '商店不可用（可能未登录 Apple ID 或网络问题）';
      } else if (_iap.products.isEmpty) {
        _iapError = '商品列表加载失败，请重试';
      }
    } on TimeoutException {
      _iapError = '加载超时，请检查网络后重试';
    } catch (e) {
      _iapError = '加载失败：$e';
    } finally {
      if (mounted) setState(() => _iapLoading = false);
    }
  }

  /// 手动补发（用户付了款但币没到账）
  Future<void> _retryPending() async {
    final count = await _iap.retryPendingReceipts();
    if (!mounted) return;
    if (count > 0) {
      _showSnack('成功补发 $count 笔交易', success: true);
      _loadOrders();
      context.read<WalletProvider>().refresh();
    } else {
      _showSnack('暂无可补发交易');
    }
    _pendingReceiptCount = await _iap.pendingReceiptsCount();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _iap.onPurchaseSuccess = null;
    _iap.onPurchaseError = null;
    _amountController.dispose();
    _txHashController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _loadingOrders = true);
    try {
      final data = await _walletService.getRechargeList();
      if (mounted) setState(() => _orders = data.list);
    } catch (e) {
      debugPrint('[RechargePage] load orders error: $e');
    }
    if (mounted) setState(() => _loadingOrders = false);
  }

  // ============================================================
  //  IAP 购买（iOS）
  // ============================================================

  Future<void> _purchase() async {
    final l = AppLocalizations.of(context)!;

    if (_selectedProductId == null) {
      _showSnack(l.get('please_select_amount'));
      return;
    }

    if (!_iap.isAvailable) {
      _showSnack(l.get('iap_unavailable'));
      return;
    }

    final idx = _iap.products.indexWhere((p) => p.id == _selectedProductId);
    if (idx < 0) {
      _showSnack(l.get('purchase_failed'));
      return;
    }
    final product = _iap.products[idx];

    // onPurchaseSuccess / onPurchaseError 已在 initState 注册，这里只需触发购买
    setState(() => _purchasing = true);

    try {
      await _iap.buyProduct(product);
    } catch (e) {
      if (mounted && _purchasing) {
        setState(() => _purchasing = false);
        _showSnack('${l.get('purchase_failed')}: $e');
      }
    }
  }

  // ============================================================
  //  USDT 充值（Web / Android）
  // ============================================================

  Future<void> _submitUsdt() async {
    final l = AppLocalizations.of(context)!;
    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final txHash = _txHashController.text.trim();

    if (amount <= 0) {
      _showSnack(l.get('please_enter_amount'));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final res = await _walletService.recharge(amount: amount, txHash: txHash);
      if (mounted) {
        if (res['code'] == 0) {
          _showSnack(l.get('recharge_submitted'), success: true);
          _amountController.clear();
          _txHashController.clear();
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

  // ============================================================
  //  Build
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final walletProvider = context.watch<WalletProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(l.get('recharge'))),
      backgroundColor: AppTheme.scaffoldBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBalanceCard(walletProvider),
            const SizedBox(height: 12),

            if (_useUsdt)
              _buildUsdtForm(l, walletProvider)
            else
              _buildIapSection(l),

            const SizedBox(height: 16),

            Text(
              _useUsdt ? l.get('recharge_history') : l.get('purchase_history'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            if (_loadingOrders)
              const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
            else if (_orders.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(l.get('no_records'), style: const TextStyle(color: AppTheme.textHint)),
                ),
              )
            else
              ..._orders.map((order) => _buildOrderItem(order, l)),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ============================================================
  //  余额卡片
  // ============================================================

  Widget _buildBalanceCard(WalletProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5BA0E8), Color(0xFF4A90D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.get('available_balance'),
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85)),
                ),
                const SizedBox(height: 4),
                CoinAmount(
                  amount: provider.balance,
                  textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  //  USDT 充值表单（Web / Android）
  // ============================================================

  Widget _buildUsdtForm(AppLocalizations l, WalletProvider walletProvider) {
    final info = walletProvider.walletInfo;
    final usdtAddress = info?.usdtAddressTrc20 ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // USDT 地址
          Text(l.get('usdt_address'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.scaffoldBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    usdtAddress.isNotEmpty ? usdtAddress : l.get('address_not_configured'),
                    style: TextStyle(
                      fontSize: 12,
                      color: usdtAddress.isNotEmpty ? AppTheme.textPrimary : AppTheme.textHint,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                if (usdtAddress.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: usdtAddress));
                      _showSnack(l.get('copied'), success: true);
                    },
                    child: const Icon(Icons.copy, size: 16, color: AppTheme.primaryColor),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          const Text('TRC20', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),

          const SizedBox(height: 10),

          // 充值金额
          Text(l.get('recharge_amount'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            '1 USDT = ${CurrencyConfig.ratePerUsdt.toInt()} ${CurrencyConfig.coinUnit}',
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              hintText: '${l.get("min_amount")}: ${CurrencyConfig.formatNumber(info?.minRecharge ?? 10)} USDT',
              prefixText: 'USDT ',
            ),
          ),
          if ((_amountController.text.trim()).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '≈ ${CurrencyConfig.format(CurrencyConfig.fromUsdt(double.tryParse(_amountController.text.trim()) ?? 0))} ${CurrencyConfig.coinUnit}',
                style: const TextStyle(fontSize: 12, color: AppTheme.successColor, fontWeight: FontWeight.w500),
              ),
            ),

          const SizedBox(height: 10),

          // 交易哈希
          Row(
            children: [
              Text('TX Hash', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              Text('(${l.get('optional')})', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _txHashController,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              hintText: l.get('enter_tx_hash'),
            ),
          ),

          const SizedBox(height: 14),

          // 提交按钮
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitUsdt,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      l.get('submit_recharge'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  //  IAP 套餐（iOS）
  // ============================================================

  Widget _buildIapSection(AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.get('coin_packs'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
            ),
            if (_pendingReceiptCount > 0)
              TextButton.icon(
                onPressed: _retryPending,
                icon: const Icon(Icons.refresh, size: 16, color: AppTheme.warningColor),
                label: Text(
                  '补发 $_pendingReceiptCount 笔',
                  style: const TextStyle(fontSize: 12, color: AppTheme.warningColor),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        if (_iapLoading)
          const Center(child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ))
        else if (_iapError != null)
          _buildErrorHint(_iapError!)
        else if (!_iap.isAvailable)
          _buildUnavailableHint(l)
        else if (_iap.products.isEmpty)
          _buildErrorHint('商品列表为空')
        else
          _buildProductGrid(),

        const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: (_iapLoading || _purchasing || _selectedProductId == null) ? null : _purchase,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _purchasing
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    l.get('purchase'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorHint(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.dangerColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: AppTheme.dangerColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(msg, style: const TextStyle(color: AppTheme.dangerColor, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 100,
            height: 32,
            child: OutlinedButton(
              onPressed: () => _initIap(force: true),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.dangerColor),
                padding: EdgeInsets.zero,
              ),
              child: const Text('重试', style: TextStyle(color: AppTheme.dangerColor, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnavailableHint(AppLocalizations l) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.warningColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(l.get('iap_unavailable'), style: const TextStyle(color: AppTheme.warningColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.6,
      ),
      itemCount: _iap.products.length,
      itemBuilder: (context, index) {
        final product = _iap.products[index];
        final coins = IapProducts.coinAmounts[product.id] ?? 0;
        final isSelected = _selectedProductId == product.id;

        return GestureDetector(
          onTap: () => setState(() => _selectedProductId = product.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryLight : AppTheme.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                width: 2,
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ] : AppTheme.cardShadow,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CoinAmount(
                  amount: coins.toDouble(),
                  iconSize: 20,
                  textStyle: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? AppTheme.primaryDark : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  product.price,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  //  订单记录
  // ============================================================

  Widget _buildOrderItem(RechargeOrderModel order, AppLocalizations l) {
    Color statusColor;
    String statusText;
    if (order.isIap) {
      statusColor = AppTheme.successColor;
      statusText = l.get('auto_approved');
    } else if (order.isPending) {
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
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoinAmount(
                  amount: order.amount,
                  iconSize: 14,
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
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
