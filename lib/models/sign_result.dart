/// 签到结果
class SignResultModel {
  final double reward;
  final double baseReward;
  final int bonusRate;
  final bool isBonus;
  final int currentStreak;
  final int dayInCycle;
  final int totalSignDays;
  final double rewardFrozenBalance;

  SignResultModel({
    this.reward = 0,
    this.baseReward = 0,
    this.bonusRate = 1,
    this.isBonus = false,
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
      currentStreak: json['current_streak'] ?? 0,
      dayInCycle: json['day_in_cycle'] ?? 0,
      totalSignDays: json['total_sign_days'] ?? 0,
      rewardFrozenBalance: double.tryParse('${json['reward_frozen_balance']}') ?? 0,
    );
  }
}
