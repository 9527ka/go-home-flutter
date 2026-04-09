import '../config/currency.dart';
import 'user.dart';

/// 爱心中心记录
class WalletTransactionModel {
  final int id;
  final int userId;
  final int type;
  final String typeText;
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final String? relatedType;
  final int? relatedId;
  final String remark;
  final String createdAt;
  final UserModel? user;

  WalletTransactionModel({
    required this.id,
    this.userId = 0,
    required this.type,
    this.typeText = '',
    required this.amount,
    this.balanceBefore = 0,
    this.balanceAfter = 0,
    this.relatedType,
    this.relatedId,
    this.remark = '',
    required this.createdAt,
    this.user,
  });

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    return WalletTransactionModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      type: json['type'] ?? 0,
      typeText: json['type_text'] ?? '',
      amount: double.tryParse('${json['amount']}') ?? 0,
      balanceBefore: double.tryParse('${json['balance_before']}') ?? 0,
      balanceAfter: double.tryParse('${json['balance_after']}') ?? 0,
      relatedType: json['related_type'],
      relatedId: json['related_id'],
      remark: json['remark'] ?? '',
      createdAt: json['created_at'] ?? '',
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
    );
  }

  /// 是否收入类型
  bool get isIncome => const [1, 4, 7, 8, 9].contains(type);

  /// 显示数量（带+/-符号和币种符号）
  String get displayAmount => CurrencyConfig.formatSigned(amount, isIncome: isIncome);
}
