import 'user.dart';

/// 爱心中心信息
class WalletModel {
  final int userId;
  final double balance;
  final double frozenBalance;
  final double rewardFrozenBalance;
  final double totalRecharge;
  final double totalWithdrawal;
  final double totalDonation;
  final double totalRewardEarned;
  final int status; // 1=正常 0=冻结

  WalletModel({
    required this.userId,
    this.balance = 0,
    this.frozenBalance = 0,
    this.rewardFrozenBalance = 0,
    this.totalRecharge = 0,
    this.totalWithdrawal = 0,
    this.totalDonation = 0,
    this.totalRewardEarned = 0,
    this.status = 1,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      userId: json['user_id'] ?? 0,
      balance: double.tryParse('${json['balance']}') ?? 0,
      frozenBalance: double.tryParse('${json['frozen_balance']}') ?? 0,
      rewardFrozenBalance: double.tryParse('${json['reward_frozen_balance']}') ?? 0,
      totalRecharge: double.tryParse('${json['total_recharged']}') ?? 0,
      totalWithdrawal: double.tryParse('${json['total_withdrawn']}') ?? 0,
      totalDonation: double.tryParse('${json['total_donated']}') ?? 0,
      totalRewardEarned: double.tryParse('${json['total_reward_earned']}') ?? 0,
      status: json['status'] ?? 1,
    );
  }

  double get availableBalance => balance;
  bool get isNormal => status == 1;
}

/// 爱心中心信息 + 配置（info 接口返回）
class WalletInfoModel {
  final WalletModel wallet;
  final String usdtAddressTrc20;
  final String usdtAddressErc20;
  final double minRecharge;
  final double minWithdrawal;
  final double withdrawalFeeRate;
  final double minDonation;
  final double boostHourlyRate;

  WalletInfoModel({
    required this.wallet,
    this.usdtAddressTrc20 = '',
    this.usdtAddressErc20 = '',
    this.minRecharge = 10,
    this.minWithdrawal = 20,
    this.withdrawalFeeRate = 0,
    this.minDonation = 1,
    this.boostHourlyRate = 10,
  });

  factory WalletInfoModel.fromJson(Map<String, dynamic> json) {
    // 后端 /api/wallet/info 返回结构：
    // { balance, frozen_balance, ... , settings: { usdt_address_trc20, ... } }
    // 钱包字段在根级别，配置字段嵌套在 settings 下
    final settings = json['settings'] as Map<String, dynamic>? ?? {};
    return WalletInfoModel(
      wallet: WalletModel.fromJson(json),
      usdtAddressTrc20: settings['usdt_address_trc20'] ?? '',
      usdtAddressErc20: settings['usdt_address_erc20'] ?? '',
      minRecharge: double.tryParse('${settings['min_recharge']}') ?? 10,
      minWithdrawal: double.tryParse('${settings['min_withdrawal']}') ?? 20,
      withdrawalFeeRate: double.tryParse('${settings['withdrawal_fee_rate']}') ?? 0,
      minDonation: double.tryParse('${settings['min_donation']}') ?? 1,
      boostHourlyRate: double.tryParse('${settings['boost_hourly_rate']}') ?? 10,
    );
  }
}
