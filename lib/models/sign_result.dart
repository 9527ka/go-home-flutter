/// 签到结果
class SignResultModel {
  final double reward;              // 最终到账（含 VIP 加成 & 暴击）
  final double baseReward;          // 当天基础奖励（未加成）
  final int bonusRate;              // 暴击倍率 1/2/5/10/20
  final bool isBonus;
  final String vipLevelKey;
  final double vipSignBonusRate;    // 0~0.4 decimal
  final int currentStreak;
  final int dayInCycle;
  final int totalSignDays;
  final double rewardFrozenBalance;

  SignResultModel({
    this.reward = 0,
    this.baseReward = 0,
    this.bonusRate = 1,
    this.isBonus = false,
    this.vipLevelKey = 'normal',
    this.vipSignBonusRate = 0,
    this.currentStreak = 0,
    this.dayInCycle = 0,
    this.totalSignDays = 0,
    this.rewardFrozenBalance = 0,
  });

  factory SignResultModel.fromJson(Map<String, dynamic> json) {
    return SignResultModel(
      reward: double.tryParse('${json['reward']}') ?? 0,
      baseReward: double.tryParse('${json['base_reward']}') ?? 0,
      bonusRate: json['bonus_rate'] ?? 1,
      isBonus: json['is_bonus'] ?? false,
      vipLevelKey: json['vip_level_key'] ?? 'normal',
      vipSignBonusRate: double.tryParse('${json['vip_sign_bonus_rate']}') ?? 0,
      currentStreak: json['current_streak'] ?? 0,
      dayInCycle: json['day_in_cycle'] ?? 0,
      totalSignDays: json['total_sign_days'] ?? 0,
      rewardFrozenBalance: double.tryParse('${json['reward_frozen_balance']}') ?? 0,
    );
  }
}
