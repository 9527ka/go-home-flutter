import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/wallet_provider.dart';
import '../../config/currency.dart';
import '../../models/wallet_transaction.dart';
import '../../widgets/coin_icon.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  @override
  void initState() {
    super.initState();
    final provider = context.read<WalletProvider>();
    provider.loadWalletInfo();
    provider.loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final provider = context.watch<WalletProvider>();

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: RefreshIndicator(
        onRefresh: () async {
          await provider.loadWalletInfo();
          await provider.loadTransactions();
        },
        child: CustomScrollView(
          slivers: [
            // 渐变头部 + 爱心值卡片
            SliverToBoxAdapter(
              child: _buildHeader(context, provider, l),
            ),

            // 操作按钮
            SliverToBoxAdapter(
              child: _buildActions(context, l),
            ),

            // 近期记录标题
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l.get('recent_transactions'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.walletTransactions),
                      child: Text(l.get('view_all')),
                    ),
                  ],
                ),
              ),
            ),

            // 记录列表
            if (provider.isLoadingTransactions && provider.transactions.isEmpty)
              const SliverToBoxAdapter(
                child: Center(child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                )),
              )
            else if (provider.transactions.isEmpty)
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 48, color: AppTheme.textHint),
                        const SizedBox(height: 12),
                        Text(l.get('no_transactions'), style: const TextStyle(color: AppTheme.textHint)),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final tx = provider.transactions[index];
                    return _buildTransactionItem(tx);
                  },
                  childCount: provider.transactions.length.clamp(0, 20),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WalletProvider provider, AppLocalizations l) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 24,
        right: 24,
        bottom: 28,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5BA0E8), Color(0xFF4A90D9)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        children: [
          // 导航栏
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
                ),
              ),
              Expanded(
                child: Text(
                  l.get('my_wallet'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
              const SizedBox(width: 36),
            ],
          ),
          const SizedBox(height: 28),

          // 爱心值
          if (provider.isLoading && provider.walletInfo == null)
            const CircularProgressIndicator(color: Colors.white)
          else ...[
            Text(
              l.get('available_balance'),
              style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8)),
            ),
            const SizedBox(height: 8),
            CoinAmount(
              amount: provider.balance,
              iconSize: 28,
              textStyle: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            if (provider.frozenBalance > 0) ...[
              const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text('${l.get('frozen')}: ', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.7))),
                CoinAmount(
                  amount: provider.frozenBalance,
                  iconSize: 12,
                  textStyle: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.7)),
                ),
              ]),
            ],
            if ((provider.wallet?.rewardFrozenBalance ?? 0) > 0) ...[
              const SizedBox(height: 2),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text('奖励待释放: ', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.7))),
                CoinAmount(
                  amount: provider.wallet?.rewardFrozenBalance ?? 0,
                  iconSize: 12,
                  textStyle: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.7)),
                ),
              ]),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _actionButton(
              icon: Icons.add_circle_outline,
              label: l.get('recharge'),
              color: AppTheme.successColor,
              onTap: () => Navigator.pushNamed(context, AppRoutes.walletRecharge).then((_) {
                context.read<WalletProvider>().refresh();
              }),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _actionButton(
              icon: Icons.arrow_circle_up_outlined,
              label: l.get('withdraw'),
              color: AppTheme.primaryColor,
              onTap: () => Navigator.pushNamed(context, AppRoutes.walletWithdraw).then((_) {
                context.read<WalletProvider>().refresh();
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(WalletTransactionModel tx) {
    final isIncome = tx.isIncome;
    final color = isIncome ? AppTheme.successColor : AppTheme.dangerColor;

    IconData icon;
    switch (tx.type) {
      case 1: icon = Icons.add_circle; break;      // 获取
      case 2: icon = Icons.arrow_circle_up; break;  // 发放
      case 3: icon = Icons.favorite; break;          // 支持支出
      case 4: icon = Icons.favorite_border; break;   // 收到支持
      case 5: icon = Icons.rocket_launch; break;     // 曝光
      case 6: icon = Icons.redeem; break;            // 发红包
      case 7: icon = Icons.redeem; break;            // 收红包
      case 8: icon = Icons.replay; break;            // 红包退回
      case 9: icon = Icons.replay; break;            // 发放退回
      case 10: icon = Icons.calendar_today; break;   // 签到奖励
      case 11: icon = Icons.task_alt; break;          // 任务奖励
      case 12: icon = Icons.lock_open; break;         // 奖励释放
      default: icon = Icons.receipt;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                const SizedBox(height: 2),
                Text(
                  tx.createdAt,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
                ),
              ],
            ),
          ),
          CoinAmount(
            amount: tx.amount,
            prefix: tx.isIncome ? '+' : '-',
            iconSize: 14,
            textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}
