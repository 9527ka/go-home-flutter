import 'user.dart';

/// 获取订单
class RechargeOrderModel {
  final int id;
  final int userId;
  final String orderNo;
  final double amount;
  final String? txHash;
  final String? screenshotUrl;
  final int status; // 0=待审核 1=已通过 2=已拒绝
  final String? statusText;
  final String? adminRemark;
  final String createdAt;
  final String? processedAt;
  final UserModel? user;
  final int paymentType; // 0=USDT, 1=Apple IAP
  final String? iapProductId;

  RechargeOrderModel({
    required this.id,
    this.userId = 0,
    this.orderNo = '',
    required this.amount,
    this.txHash,
    this.screenshotUrl,
    this.status = 0,
    this.statusText,
    this.adminRemark,
    required this.createdAt,
    this.processedAt,
    this.user,
    this.paymentType = 0,
    this.iapProductId,
  });

  factory RechargeOrderModel.fromJson(Map<String, dynamic> json) {
    return RechargeOrderModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      orderNo: json['order_no'] ?? '',
      amount: double.tryParse('${json['amount']}') ?? 0,
      txHash: json['tx_hash'],
      screenshotUrl: json['screenshot_url'],
      status: json['status'] ?? 0,
      statusText: json['status_text'],
      adminRemark: json['admin_remark'],
      createdAt: json['created_at'] ?? '',
      processedAt: json['processed_at'],
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
      paymentType: json['payment_type'] ?? 0,
      iapProductId: json['iap_product_id'],
    );
  }

  bool get isPending => status == 0;
  bool get isApproved => status == 1;
  bool get isRejected => status == 2;
  bool get isIap => paymentType == 1;
}
