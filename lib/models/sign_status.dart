/// 签到状态
class SignStatusModel {
  final bool signedToday;
  final int currentStreak;
  final int dayInCycle;
  final double todayReward;       // 含 VIP 签到加成（不含暴击）
  final double baseTodayReward;   // 不含任何加成的基础奖励
  final int totalSignDays;
  final List<double> rewardsConfig;
  final List<bool> weekStatus;
  final String vipLevelKey;
  final double vipSignBonusRate;  // 0~0.4 decimal
  final int vipCritMax;           // 允许的最大暴击倍率 5/10/20

  SignStatusModel({
    this.signedToday = false,
    this.currentStreak = 0,
    this.dayInCycle = 1,
    this.todayReward = 0,
    this.baseTodayReward = 0,
    this.totalSignDays = 0,
    this.rewardsConfig = const [0.1, 0.2, 0.3, 0.5, 0.8, 1, 2],
    this.weekStatus = const [false, false, false, false, false, false, false],
    this.vipLevelKey = 'normal',
    this.vipSignBonusRate = 0,
    this.vipCritMax = 5,
  });

  factory SignStatusModel.fromJson(Map<String, dynamic> json) {
    return SignStatusModel(
      signedToday: json['signed_today'] ?? false,
      currentStreak: json['current_streak'] ?? 0,
      dayInCycle: json['day_in_cycle'] ?? 1,
      todayReward: double.tryParse('${json['today_reward']}') ?? 0,
      baseTodayReward: double.tryParse('${json['base_today_reward']}') ?? 0,
      totalSignDays: json['total_sign_days'] ?? 0,
      rewardsConfig: (json['rewards_config'] as List<dynamic>?)
              ?.map((e) => double.tryParse('$e') ?? 0)
              .toList() ??
          [0.1, 0.2, 0.3, 0.5, 0.8, 1, 2],
      weekStatus: (json['week_status'] as List<dynamic>?)
              ?.map((e) => e == true)
              .toList() ??
          List.filled(7, false),
      vipLevelKey: json['vip_level_key'] ?? 'normal',
      vipSignBonusRate: double.tryParse('${json['vip_sign_bonus_rate']}') ?? 0,
      vipCritMax: (json['vip_crit_max'] as num?)?.toInt() ?? 5,
    );
  }
}
