import '../config/api.dart';
import '../models/api_response.dart';
import '../models/wallet.dart';
import '../models/wallet_transaction.dart';
import '../models/recharge_order.dart';
import '../models/withdrawal_order.dart';
import '../models/red_packet.dart';
import 'http_client.dart';

class WalletService {
  final _http = HttpClient();

  /// 获取爱心中心信息 + 配置
  Future<WalletInfoModel?> getInfo() async {
    final res = await _http.get(ApiConfig.walletInfo);
    if (res['code'] == 0 && res['data'] != null) {
      return WalletInfoModel.fromJson(res['data']);
    }
    return null;
  }

  /// 明细列表
  Future<PageData<WalletTransactionModel>> getTransactions({
    int page = 1,
    int? type,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (type != null) params['type'] = type;

    final res = await _http.get(ApiConfig.walletTransactions, params: params);
    if (res['code'] == 0 && res['data'] != null) {
      return PageData.fromJson(
        res['data'],
        (json) => WalletTransactionModel.fromJson(json),
      );
    }
    return PageData(list: [], page: 1, pageSize: 20, total: 0);
  }

  /// 提交获取申请（USDT 手动充值）
  Future<Map<String, dynamic>> recharge({
    required double amount,
    String txHash = '',
    String? screenshotUrl,
  }) async {
    return await _http.post(ApiConfig.walletRecharge, data: {
      'amount': amount,
      'tx_hash': txHash,
      if (screenshotUrl != null) 'screenshot_url': screenshotUrl,
    });
  }

  /// Apple IAP 充值（收据验证 + 自动到账）
  Future<Map<String, dynamic>> iapRecharge({
    required String receiptData,
    required String productId,
  }) async {
    return await _http.post(ApiConfig.walletIapRecharge, data: {
      'receipt_data': receiptData,
      'product_id': productId,
    });
  }

  /// 我的获取记录
  Future<PageData<RechargeOrderModel>> getRechargeList({int page = 1}) async {
    final res = await _http.get(ApiConfig.walletRechargeList, params: {'page': page});
    if (res['code'] == 0 && res['data'] != null) {
      return PageData.fromJson(
        res['data'],
        (json) => RechargeOrderModel.fromJson(json),
      );
    }
    return PageData(list: [], page: 1, pageSize: 20, total: 0);
  }

  /// 提交发放申请
  Future<Map<String, dynamic>> withdraw({
    required double amount,
    required String walletAddress,
    String chainType = 'TRC20',
  }) async {
    return await _http.post(ApiConfig.walletWithdraw, data: {
      'amount': amount,
      'wallet_address': walletAddress,
      'chain_type': chainType,
    });
  }

  /// 我的发放记录
  Future<PageData<WithdrawalOrderModel>> getWithdrawList({int page = 1}) async {
    final res = await _http.get(ApiConfig.walletWithdrawList, params: {'page': page});
    if (res['code'] == 0 && res['data'] != null) {
      return PageData.fromJson(
        res['data'],
        (json) => WithdrawalOrderModel.fromJson(json),
      );
    }
    return PageData(list: [], page: 1, pageSize: 20, total: 0);
  }

  /// 支持
  Future<Map<String, dynamic>> donate({
    required int postId,
    required double amount,
    String message = '',
    bool isAnonymous = false,
  }) async {
    return await _http.post(ApiConfig.walletDonate, data: {
      'post_id': postId,
      'amount': amount,
      'message': message,
      'is_anonymous': isAnonymous ? 1 : 0,
    });
  }

  /// 购买置顶/推广
  Future<Map<String, dynamic>> boost({
    required int postId,
    required int hours,
  }) async {
    return await _http.post(ApiConfig.walletBoost, data: {
      'post_id': postId,
      'hours': hours,
    });
  }

  /// 查询启事是否有活跃置顶
  /// 返回 {is_boosted: bool, expire_at: String?}
  Future<Map<String, dynamic>?> getBoostActive(int postId) async {
    final res = await _http.get(ApiConfig.walletBoostActive, params: {'post_id': postId});
    if (res['code'] == 0 && res['data'] != null) {
      return Map<String, dynamic>.from(res['data']);
    }
    return null;
  }

  /// 发放悬赏
  Future<Map<String, dynamic>> rewardPay({
    required int postId,
    required int clueId,
    required double amount,
    String message = '',
  }) async {
    return await _http.post(ApiConfig.walletRewardPay, data: {
      'post_id': postId,
      'clue_id': clueId,
      'amount': amount,
      'message': message,
    });
  }

  /// 发红包
  Future<Map<String, dynamic>> sendRedPacket({
    required int targetType,
    required int targetId,
    required double totalAmount,
    required int totalCount,
    String greeting = '',
  }) async {
    return await _http.post(ApiConfig.redPacketSend, data: {
      'target_type': targetType,
      'target_id': targetId,
      'total_amount': totalAmount,
      'total_count': totalCount,
      'greeting': greeting,
    });
  }

  /// 抢红包
  Future<Map<String, dynamic>> claimRedPacket(int redPacketId) async {
    return await _http.post(ApiConfig.redPacketClaim, data: {
      'red_packet_id': redPacketId,
    });
  }

  /// 红包详情
  Future<RedPacketModel?> getRedPacketDetail(int id) async {
    final res = await _http.get(ApiConfig.redPacketDetail, params: {'id': id});
    if (res['code'] == 0 && res['data'] != null) {
      return RedPacketModel.fromJson(res['data']);
    }
    return null;
  }
}
