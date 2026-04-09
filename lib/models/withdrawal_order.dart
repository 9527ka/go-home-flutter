import 'user.dart';

/// 发放订单
class WithdrawalOrderModel {
  final int id;
  final int userId;
  final String orderNo;
  final double amount;
  final double fee;
  final double netAmount;
  final String walletAddress;
  final String chainType;
  final int status; // 0=待审核 1=已通过 2=已拒绝 3=已完成
  final String? statusText;
  final String? txHash;
  final String? adminRemark;
  final String createdAt;
  final String? processedAt;
  final UserModel? user;

  WithdrawalOrderModel({
    required this.id,
    this.userId = 0,
    this.orderNo = '',
    required this.amount,
    this.fee = 0,
    this.netAmount = 0,
    this.walletAddress = '',
    this.chainType = 'TRC20',
    this.status = 0,
    this.statusText,
    this.txHash,
    this.adminRemark,
    required this.createdAt,
    this.processedAt,
    this.user,
  });

  factory WithdrawalOrderModel.fromJson(Map<String, dynamic> json) {
    return WithdrawalOrderModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      orderNo: json['order_no'] ?? '',
      amount: double.tryParse('${json['amount']}') ?? 0,
      fee: double.tryParse('${json['fee']}') ?? 0,
      netAmount: double.tryParse('${json['net_amount']}') ?? 0,
      walletAddress: json['wallet_address'] ?? '',
      chainType: json['chain_type'] ?? 'TRC20',
      status: json['status'] ?? 0,
      statusText: json['status_text'],
      txHash: json['tx_hash'],
      adminRemark: json['admin_remark'],
      createdAt: json['created_at'] ?? '',
      processedAt: json['processed_at'],
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
    );
  }

  bool get isPending => status == 0;
  bool get isApproved => status == 1;
  bool get isRejected => status == 2;
  bool get isCompleted => status == 3;
}
