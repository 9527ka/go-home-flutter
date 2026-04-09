import 'package:flutter/material.dart';
import '../../config/currency.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/wallet_service.dart';
import '../../models/wallet_transaction.dart';
import '../../models/api_response.dart';

class TransactionHistoryPage extends StatefulWidget {
  const TransactionHistoryPage({super.key});

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _walletService = WalletService();
  final _scrollController = ScrollController();

  List<WalletTransactionModel> _list = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  int? _currentType;

  // Tab 类型映射: null=全部, 1=获取, 2=发放, 3+4=支持, 6+7=红包, 5=曝光
  static const _tabTypes = <int?>[null, 1, 2, null, null, 5];
  // 捐赠和红包需要特殊处理（两种类型合并）

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    _page = 1;
    _hasMore = true;
    _list.clear();

    final idx = _tabController.index;
    switch (idx) {
      case 0: _currentType = null; break;
      case 1: _currentType = 1; break;
      case 2: _currentType = 2; break;
      case 3: _currentType = null; break; // 支持 - 客户端过滤
      case 4: _currentType = null; break; // 红包 - 客户端过滤
      case 5: _currentType = 5; break;
    }
    _loadData();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      _loadMore();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _walletService.getTransactions(page: 1, type: _currentType);
      var items = data.list;

      // 客户端过滤支持/红包
      final tabIdx = _tabController.index;
      if (tabIdx == 3) {
        items = items.where((t) => t.type == 3 || t.type == 4).toList();
      } else if (tabIdx == 4) {
        items = items.where((t) => t.type == 6 || t.type == 7 || t.type == 8).toList();
      }

      if (mounted) {
        setState(() {
          _list = items;
          _hasMore = data.hasMore;
          _page = 1;
        });
      }
    } catch (e) { debugPrint('[TransactionHistoryPage] load data error: $e'); }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);
    try {
      final data = await _walletService.getTransactions(page: _page + 1, type: _currentType);
      var items = data.list;

      final tabIdx = _tabController.index;
      if (tabIdx == 3) {
        items = items.where((t) => t.type == 3 || t.type == 4).toList();
      } else if (tabIdx == 4) {
        items = items.where((t) => t.type == 6 || t.type == 7 || t.type == 8).toList();
      }

      if (mounted) {
        setState(() {
          _list.addAll(items);
          _hasMore = data.hasMore;
          _page++;
        });
      }
    } catch (e) { debugPrint('[TransactionHistoryPage] load more error: $e'); }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.get('transaction_history')),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryColor,
          tabs: [
            Tab(text: l.get('all')),
            Tab(text: l.get('recharge')),
            Tab(text: l.get('withdraw')),
            Tab(text: l.get('donation')),
            Tab(text: l.get('red_packet')),
            Tab(text: l.get('boost')),
          ],
        ),
      ),
      backgroundColor: AppTheme.scaffoldBg,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _list.isEmpty && !_isLoading
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 48, color: AppTheme.textHint),
                    const SizedBox(height: 12),
                    Text(l.get('no_transactions'), style: const TextStyle(color: AppTheme.textHint)),
                  ],
                ),
              )
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _list.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _list.length) {
                    return const Center(child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ));
                  }
                  return _buildItem(_list[index]);
                },
              ),
      ),
    );
  }

  Widget _buildItem(WalletTransactionModel tx) {
    final isIncome = tx.isIncome;
    final color = isIncome ? AppTheme.successColor : AppTheme.dangerColor;

    IconData icon;
    switch (tx.type) {
      case 1: icon = Icons.add_circle; break;
      case 2: icon = Icons.arrow_circle_up; break;
      case 3: icon = Icons.favorite; break;
      case 4: icon = Icons.favorite_border; break;
      case 5: icon = Icons.rocket_launch; break;
      case 6: icon = Icons.redeem; break;
      case 7: icon = Icons.redeem; break;
      case 8: icon = Icons.replay; break;
      case 9: icon = Icons.replay; break;
      default: icon = Icons.receipt;
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
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.typeText.isNotEmpty ? tx.typeText : tx.remark,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary),
                ),
                if (tx.remark.isNotEmpty && tx.typeText.isNotEmpty)
                  Text(tx.remark, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 2),
                Text(tx.createdAt, style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                tx.displayAmount,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color),
              ),
              Text(
                '${AppLocalizations.of(context)!.get("balance")}: ${CurrencyConfig.format(tx.balanceAfter)}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
