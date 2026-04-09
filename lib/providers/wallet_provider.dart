import 'package:flutter/material.dart';
import '../models/wallet.dart';
import '../models/wallet_transaction.dart';
import '../models/recharge_order.dart';
import '../models/withdrawal_order.dart';
import '../services/wallet_service.dart';

class WalletProvider extends ChangeNotifier {
  final _service = WalletService();

  WalletInfoModel? _walletInfo;
  List<WalletTransactionModel> _transactions = [];
  bool _isLoading = false;
  bool _isLoadingTransactions = false;
  int _transactionPage = 1;
  bool _hasMoreTransactions = true;

  WalletInfoModel? get walletInfo => _walletInfo;
  WalletModel? get wallet => _walletInfo?.wallet;
  double get balance => _walletInfo?.wallet.balance ?? 0;
  double get frozenBalance => _walletInfo?.wallet.frozenBalance ?? 0;
  List<WalletTransactionModel> get transactions => _transactions;
  bool get isLoading => _isLoading;
  bool get isLoadingTransactions => _isLoadingTransactions;
  bool get hasMoreTransactions => _hasMoreTransactions;

  /// 加载爱心中心信息
  Future<void> loadWalletInfo() async {
    _isLoading = true;
    notifyListeners();

    try {
      _walletInfo = await _service.getInfo();
    } catch (e) {
      debugPrint('[WalletProvider] loadWalletInfo error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 加载明细（首页）
  Future<void> loadTransactions({int? type}) async {
    _isLoadingTransactions = true;
    _transactionPage = 1;
    notifyListeners();

    try {
      final data = await _service.getTransactions(page: 1, type: type);
      _transactions = data.list;
      _hasMoreTransactions = data.hasMore;
      _transactionPage = 1;
    } catch (e) {
      debugPrint('[WalletProvider] loadTransactions error: $e');
    }

    _isLoadingTransactions = false;
    notifyListeners();
  }

  /// 加载更多明细
  Future<void> loadMoreTransactions({int? type}) async {
    if (_isLoadingTransactions || !_hasMoreTransactions) return;

    _isLoadingTransactions = true;
    notifyListeners();

    try {
      final data = await _service.getTransactions(
        page: _transactionPage + 1,
        type: type,
      );
      _transactions.addAll(data.list);
      _hasMoreTransactions = data.hasMore;
      _transactionPage++;
    } catch (e) {
      debugPrint('[WalletProvider] loadMoreTransactions error: $e');
    }

    _isLoadingTransactions = false;
    notifyListeners();
  }

  /// 刷新爱心中心信息和明细（用于操作后刷新）
  Future<void> refresh() async {
    await Future.wait([loadWalletInfo(), loadTransactions()]);
  }
}
