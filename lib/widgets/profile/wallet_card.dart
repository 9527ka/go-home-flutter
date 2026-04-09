import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/coin_icon.dart';

/// Wallet / love center card displayed prominently at the top of the menu area.
class WalletCard extends StatelessWidget {
  const WalletCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final walletProvider = context.watch<WalletProvider>();
    final balance = walletProvider.walletInfo?.wallet.balance ?? 0.0;
    final frozenReward = walletProvider.walletInfo?.wallet.rewardFrozenBalance ?? 0.0;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.wallet),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF7EAED4), Color(0xFF6A9DC6)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: const Color(0xFFF97316).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            // Heart icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.favorite, size: 26, color: Colors.white),
            ),
            const SizedBox(width: 16),
            // Balance info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.get('my_wallet'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  CoinAmount(
                    amount: balance,
                    iconSize: 20,
                    textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  if (frozenReward > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('${l.get('my_wallet_subtitle')}  |  \u5F85\u91CA\u653E: ', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8))),
                        CoinAmount(
                          amount: frozenReward,
                          iconSize: 10,
                          textStyle: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8)),
                        ),
                      ]),
                    )
                  else
                    Text(
                      l.get('my_wallet_subtitle'),
                      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.8), size: 24),
          ],
        ),
      ),
    );
  }
}
