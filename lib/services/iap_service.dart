import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import '../config/iap_products.dart';
import 'wallet_service.dart';

/// Apple In-App Purchase 服务（单例，懒加载）
///
/// 管理完整购买生命周期：初始化 → 加载产品 → 购买 → 收据验证 → 完成交易
/// StoreKit 初始化延迟到首次调用 initialize() 时，避免拖慢 App 启动。
class IapService {
  IapService._();
  static final IapService instance = IapService._();

  InAppPurchase? _iap;
  final WalletService _walletService = WalletService();

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _isPurchasing = false;
  bool _initialized = false;
  Completer<void>? _initCompleter;
  static bool _storeKit1Configured = false;

  /// 购买结果回调
  VoidCallback? onPurchaseSuccess;
  void Function(String error)? onPurchaseError;

  List<ProductDetails> get products => _products;
  bool get isAvailable => _isAvailable;
  bool get isPurchasing => _isPurchasing;

  /// 配置 StoreKit1（仅执行一次，必须在访问 InAppPurchase.instance 之前）
  static void _ensureStoreKit1() {
    if (_storeKit1Configured) return;
    _storeKit1Configured = true;
    if (Platform.isIOS) {
      // ignore: deprecated_member_use
      InAppPurchaseStoreKitPlatform.enableStoreKit1();
    }
  }

  /// 懒加载 InAppPurchase 实例
  InAppPurchase get _purchase {
    _ensureStoreKit1();
    return _iap ??= InAppPurchase.instance;
  }

  /// 初始化 IAP，监听购买流（懒加载，仅在需要时调用）
  Future<void> initialize() async {
    if (_initialized) return;

    // 防止并发初始化
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }
    _initCompleter = Completer<void>();

    try {
      _isAvailable = await _purchase.isAvailable().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('[IapService] isAvailable() timeout');
          return false;
        },
      );
      if (!_isAvailable) {
        debugPrint('[IapService] Store not available');
        return;
      }

      _subscription = _purchase.purchaseStream.listen(
        _handlePurchaseUpdates,
        onDone: () => _subscription?.cancel(),
        onError: (error) => debugPrint('[IapService] Stream error: $error'),
      );

      _initialized = true;
      await loadProducts();
    } finally {
      _initCompleter!.complete();
    }
  }

  /// 等待初始化完成（供页面使用）
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    if (_initCompleter != null) {
      await _initCompleter!.future;
    } else {
      await initialize();
    }
  }

  /// 从 StoreKit 加载产品信息（含本地化价格）
  Future<void> loadProducts() async {
    if (!_isAvailable) return;

    final response = await _purchase.queryProductDetails(IapProducts.productIds);
    if (response.error != null) {
      debugPrint('[IapService] Query products error: ${response.error}');
      return;
    }

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('[IapService] Products not found: ${response.notFoundIDs}');
    }

    // 按爱心值从小到大排序
    _products = response.productDetails.toList()
      ..sort((a, b) {
        final coinsA = IapProducts.coinAmounts[a.id] ?? 0;
        final coinsB = IapProducts.coinAmounts[b.id] ?? 0;
        return coinsA.compareTo(coinsB);
      });
  }

  /// 发起消耗型购买
  Future<void> buyProduct(ProductDetails product) async {
    if (_isPurchasing) return;
    _isPurchasing = true;

    final purchaseParam = PurchaseParam(productDetails: product);
    await _purchase.buyConsumable(purchaseParam: purchaseParam);
  }

  /// 处理购买状态更新
  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _verifyAndCredit(purchase);
          break;
        case PurchaseStatus.error:
          _isPurchasing = false;
          final errorMsg = purchase.error?.message ?? 'Purchase failed';
          debugPrint('[IapService] Purchase error: $errorMsg');
          onPurchaseError?.call(errorMsg);
          // 错误时完成交易，避免 StoreKit 反复弹出
          if (purchase.pendingCompletePurchase) {
            await _purchase.completePurchase(purchase);
          }
          break;
        case PurchaseStatus.canceled:
          _isPurchasing = false;
          if (purchase.pendingCompletePurchase) {
            await _purchase.completePurchase(purchase);
          }
          break;
        case PurchaseStatus.pending:
          debugPrint('[IapService] Purchase pending...');
          break;
      }
    }
  }

  /// 向后端发送收据验证，仅成功后才完成交易
  Future<void> _verifyAndCredit(PurchaseDetails purchase) async {
    bool verified = false;

    try {
      final receiptData = purchase.verificationData.serverVerificationData;
      final productId = purchase.productID;

      final res = await _walletService.iapRecharge(
        receiptData: receiptData,
        productId: productId,
      );

      if (res['code'] == 0) {
        debugPrint('[IapService] IAP recharge success: ${res['data']}');
        verified = true;
        onPurchaseSuccess?.call();
      } else {
        debugPrint('[IapService] IAP recharge failed: ${res['msg']}');
        onPurchaseError?.call(res['msg'] ?? 'Verification failed');
      }
    } catch (e) {
      debugPrint('[IapService] Verify error: $e');
      onPurchaseError?.call('Network error during verification');
    } finally {
      _isPurchasing = false;
    }

    // 关键：仅在后端确认到账后才调用 completePurchase
    // 失败时不 complete，StoreKit 下次启动会自动重放该交易
    if (verified && purchase.pendingCompletePurchase) {
      await _purchase.completePurchase(purchase);
    }
  }

  /// 销毁
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _initialized = false;
    _initCompleter = null;
  }
}
