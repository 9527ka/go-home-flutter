/// 签到状态
class SignStatusModel {
  final bool signedToday;
  final int currentStreak;
  final int dayInCycle;
  final double todayReward;
  final int totalSignDays;
  final List<double> rewardsConfig;
  final List<bool> weekStatus;

  SignStatusModel({
    this.signedToday = false,
    this.currentStreak = 0,
    this.dayInCycle = 1,
    this.todayReward = 0,
    this.totalSignDays = 0,
    this.rewardsConfig = const [0.1, 0.2, 0.3, 0.5, 0.8, 1, 2],
    this.weekStatus = const [false, false, false, false, false, false, false],
  });

  factory SignStatusModel.fromJson(Map<String, dynamic> json) {
    return SignStatusModel(
      signedToday: json['signed_today'] ?? false,
      currentStreak: json['current_streak'] ?? 0,
      dayInCycle: json['day_in_cycle'] ?? 1,
      todayReward: double.tryParse('${json['today_reward']}') ?? 0,
      totalSignDays: json['total_sign_days'] ?? 0,
      rewardsConfig: (json['rewards_config'] as List<dynamic>?)
              ?.map((e) => double.tryParse('$e') ?? 0)
              .toList() ??
          [0.1, 0.2, 0.3, 0.5, 0.8, 1, 2],
      weekStatus: (json['week_status'] as List<dynamic>?)
              ?.map((e) => e == true)
              .toList() ??
          List.filled(7, false),
    );
  }
}
