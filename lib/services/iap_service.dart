import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/iap_products.dart';
import 'wallet_service.dart';

/// Apple In-App Purchase 服务（单例，懒加载）
///
/// 修复点：
/// 1. initialize 失败时清理 completer，允许下次重试（问题 1：第一次进入一直 loading）
/// 2. 购买后 verify 失败的收据落到本地，重启后自动重试（问题 2：付了款币没到账）
/// 3. 启动时先 flush pending transactions，消费完再允许重新购买（问题 3：duplicate_product_object）
class IapService {
  IapService._();
  static final IapService instance = IapService._();

  // 本地未完成交易持久化键
  static const _kPendingKey = 'iap_pending_receipts_v1';

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
  bool get isInitialized => _initialized;

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

  /// 初始化 IAP，监听购买流
  /// 失败路径会清理 completer 允许下次 ensureInitialized() 重试
  Future<void> initialize() async {
    if (_initialized) return;

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
        return; // finally 会清 completer 允许重试
      }

      // 监听购买流。listen 会自动 replay 之前挂起的 transactions
      _subscription = _purchase.purchaseStream.listen(
        _handlePurchaseUpdates,
        onDone: () => _subscription?.cancel(),
        onError: (error) => debugPrint('[IapService] Stream error: $error'),
      );

      await loadProducts();

      _initialized = true;

      // 后台重试本地持久化的未完成 receipt（不 await，不拖慢首屏）
      // ignore: unawaited_futures
      _retryPendingReceipts();
    } catch (e) {
      debugPrint('[IapService] initialize error: $e');
    } finally {
      _initCompleter?.complete();
      // 失败时清理 completer，下次 ensureInitialized 可重试
      if (!_initialized) {
        _initCompleter = null;
      }
    }
  }

  /// 等待初始化完成（供页面使用）
  Future<void> ensureInitialized() async {
    if (_initialized) return;
    if (_initCompleter != null) {
      await _initCompleter!.future;
      if (_initialized) return;
    }
    await initialize();
  }

  /// 强制重新初始化（忽略缓存状态）
  Future<void> forceReinitialize() async {
    _initialized = false;
    _initCompleter = null;
    _products = [];
    await initialize();
  }

  /// 从 StoreKit 加载产品信息（含本地化价格）
  Future<void> loadProducts() async {
    if (!_isAvailable) return;

    final response = await _purchase.queryProductDetails(IapProducts.productIds)
        .timeout(const Duration(seconds: 10), onTimeout: () {
      debugPrint('[IapService] queryProductDetails timeout');
      return ProductDetailsResponse(productDetails: [], notFoundIDs: []);
    });

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

    // 购买前：给 purchaseStream 时间派发挂起交易，避免 duplicate_product_object
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final purchaseParam = PurchaseParam(productDetails: product);
      await _purchase.buyConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      _isPurchasing = false;
      rethrow;
    }
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

  /// 向后端发送收据验证
  ///
  /// 关键流程：
  /// - 成功 → completePurchase + 清本地 pending
  /// - 失败 → 保存 receipt 到本地，不 completePurchase（下次启动 replay 时再试）
  /// - 连续失败 ≥ 3 次 → 强制 completePurchase 避免永久挂起，提示联系客服
  Future<void> _verifyAndCredit(PurchaseDetails purchase) async {
    final receiptData = purchase.verificationData.serverVerificationData;
    final productId = purchase.productID;
    final txId = purchase.purchaseID ?? '';

    if (receiptData.isEmpty) {
      debugPrint('[IapService] Empty receipt, completing to avoid hang');
      if (purchase.pendingCompletePurchase) {
        await _purchase.completePurchase(purchase);
      }
      _isPurchasing = false;
      onPurchaseError?.call('Empty receipt');
      return;
    }

    bool verified = false;
    String? errorMsg;

    try {
      final res = await _walletService.iapRecharge(
        receiptData: receiptData,
        productId: productId,
      );

      if (res['code'] == 0) {
        debugPrint('[IapService] IAP recharge success: ${res['data']}');
        verified = true;
      } else {
        errorMsg = res['msg']?.toString() ?? 'Verification failed';
        debugPrint('[IapService] IAP recharge failed: $errorMsg');
      }
    } catch (e) {
      errorMsg = 'Network error during verification';
      debugPrint('[IapService] Verify error: $e');
    } finally {
      _isPurchasing = false;
    }

    if (verified) {
      await _removePendingReceipt(txId);
      if (purchase.pendingCompletePurchase) {
        await _purchase.completePurchase(purchase);
      }
      onPurchaseSuccess?.call();
      return;
    }

    // 失败：持久化 receipt 以便下次重试
    final attempts = await _savePendingReceipt(
      productId: productId,
      transactionId: txId,
      receiptData: receiptData,
    );

    // 超过 3 次 → 强制 complete 避免永久卡死（用户需联系客服补发）
    if (attempts >= 3) {
      debugPrint('[IapService] Max retry reached for tx=$txId, forcing completion');
      if (purchase.pendingCompletePurchase) {
        await _purchase.completePurchase(purchase);
      }
      await _removePendingReceipt(txId);
      onPurchaseError?.call('${errorMsg ?? "验证失败"}（已重试 $attempts 次，请联系客服）');
    } else {
      onPurchaseError?.call('${errorMsg ?? "验证失败"}（将在重新进入时自动重试）');
    }
  }

  /// 后台重试本地持久化的未完成 receipt
  Future<void> _retryPendingReceipts() async {
    try {
      final list = await _loadPendingReceipts();
      if (list.isEmpty) return;
      debugPrint('[IapService] Retrying ${list.length} pending receipts');

      for (final item in list) {
        try {
          final res = await _walletService.iapRecharge(
            receiptData: item['receipt_data'] as String,
            productId: item['product_id'] as String,
          );
          if (res['code'] == 0) {
            await _removePendingReceipt(item['transaction_id'] as String);
            debugPrint('[IapService] Pending receipt retry success: ${item['transaction_id']}');
            onPurchaseSuccess?.call();
          }
        } catch (e) {
          debugPrint('[IapService] Retry pending failed: $e');
        }
      }
    } catch (e) {
      debugPrint('[IapService] _retryPendingReceipts error: $e');
    }
  }

  /// 手动触发本地未完成 receipt 重试（供 UI"重试"按钮调用）
  /// 返回成功上报的条数
  Future<int> retryPendingReceipts() async {
    final before = (await _loadPendingReceipts()).length;
    await _retryPendingReceipts();
    final after = (await _loadPendingReceipts()).length;
    return before - after;
  }

  /// 当前挂起的未完成 receipt 数量
  Future<int> pendingReceiptsCount() async {
    final list = await _loadPendingReceipts();
    return list.length;
  }

  // ============================================================
  // 本地未完成 receipt 持久化
  // ============================================================

  Future<List<Map<String, dynamic>>> _loadPendingReceipts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPendingKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// 保存失败的 receipt，返回该 transaction 的累计尝试次数
  Future<int> _savePendingReceipt({
    required String productId,
    required String transactionId,
    required String receiptData,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await _loadPendingReceipts();

    int attempts = 1;
    final idx = list.indexWhere((e) => e['transaction_id'] == transactionId);
    if (idx >= 0) {
      attempts = ((list[idx]['attempts'] as num?)?.toInt() ?? 0) + 1;
      list[idx] = {
        'product_id': productId,
        'transaction_id': transactionId,
        'receipt_data': receiptData,
        'attempts': attempts,
        'last_failed_at': DateTime.now().toIso8601String(),
      };
    } else {
      list.add({
        'product_id': productId,
        'transaction_id': transactionId,
        'receipt_data': receiptData,
        'attempts': 1,
        'last_failed_at': DateTime.now().toIso8601String(),
      });
    }

    await prefs.setString(_kPendingKey, jsonEncode(list));
    return attempts;
  }

  Future<void> _removePendingReceipt(String transactionId) async {
    if (transactionId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = await _loadPendingReceipts();
    list.removeWhere((e) => e['transaction_id'] == transactionId);
    if (list.isEmpty) {
      await prefs.remove(_kPendingKey);
    } else {
      await prefs.setString(_kPendingKey, jsonEncode(list));
    }
  }

  /// 销毁（单例场景一般不用）
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _initialized = false;
    _initCompleter = null;
  }
}
