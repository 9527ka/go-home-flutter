/// 抽奖奖池
class LotteryPoolModel {
  final int id;
  final String poolKey;
  final String name;
  final double costPerDraw;
  final int dailyDrawLimit;
  final int rateLimitSeconds;
  final double bigPrizeThreshold;
  final bool isEnabled;

  const LotteryPoolModel({
    required this.id,
    this.poolKey = 'main',
    this.name = '',
    this.costPerDraw = 100,
    this.dailyDrawLimit = 100,
    this.rateLimitSeconds = 1,
    this.bigPrizeThreshold = 500,
    this.isEnabled = true,
  });

  factory LotteryPoolModel.fromJson(Map<String, dynamic> json) {
    return LotteryPoolModel(
      id: json['id'] ?? 0,
      poolKey: json['pool_key'] ?? 'main',
      name: json['name'] ?? '',
      costPerDraw: double.tryParse('${json['cost_per_draw']}') ?? 100,
      dailyDrawLimit: (json['daily_draw_limit'] as num?)?.toInt() ?? 100,
      rateLimitSeconds: (json['rate_limit_seconds'] as num?)?.toInt() ?? 1,
      bigPrizeThreshold: double.tryParse('${json['big_prize_threshold']}') ?? 500,
      isEnabled: json['is_enabled'] == true || json['is_enabled'] == 1,
    );
  }
}

/// 抽奖奖品档位
class LotteryPrizeModel {
  final int id;
  final int poolId;
  final String name;
  final double rewardAmount;
  final int weight;
  final int rarity; // 0普通 1稀有 2史诗 3传说
  final String iconUrl;
  final int sortOrder;

  const LotteryPrizeModel({
    required this.id,
    this.poolId = 0,
    required this.name,
    this.rewardAmount = 0,
    this.weight = 0,
    this.rarity = 0,
    this.iconUrl = '',
    this.sortOrder = 0,
  });

  factory LotteryPrizeModel.fromJson(Map<String, dynamic> json) {
    return LotteryPrizeModel(
      id: json['id'] ?? 0,
      poolId: json['pool_id'] ?? 0,
      name: json['name'] ?? '',
      rewardAmount: double.tryParse('${json['reward_amount']}') ?? 0,
      weight: (json['weight'] as num?)?.toInt() ?? 0,
      rarity: (json['rarity'] as num?)?.toInt() ?? 0,
      iconUrl: json['icon_url'] ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isThanks => rewardAmount == 0;
}

/// 抽奖页信息
class LotteryInfoModel {
  final LotteryPoolModel pool;
  final List<LotteryPrizeModel> prizes;
  final int todayDrawCount;
  final int todayRemaining;

  const LotteryInfoModel({
    required this.pool,
    this.prizes = const [],
    this.todayDrawCount = 0,
    this.todayRemaining = 0,
  });

  factory LotteryInfoModel.fromJson(Map<String, dynamic> json) {
    return LotteryInfoModel(
      pool: LotteryPoolModel.fromJson(json['pool'] ?? {}),
      prizes: (json['prizes'] as List?)
              ?.map((e) => LotteryPrizeModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      todayDrawCount: (json['today_draw_count'] as num?)?.toInt() ?? 0,
      todayRemaining: (json['today_remaining'] as num?)?.toInt() ?? 0,
    );
  }
}

/// 抽奖结果
class LotteryResultModel {
  final int logId;
  final int prizeId;
  final String prizeName;
  final double rewardAmount;
  final int rarity;
  final bool isBigPrize;
  final double cost;
  final double balanceAfter;

  const LotteryResultModel({
    required this.logId,
    required this.prizeId,
    required this.prizeName,
    required this.rewardAmount,
    this.rarity = 0,
    this.isBigPrize = false,
    this.cost = 0,
    this.balanceAfter = 0,
  });

  factory LotteryResultModel.fromJson(Map<String, dynamic> json) {
    return LotteryResultModel(
      logId: json['log_id'] ?? 0,
      prizeId: json['prize_id'] ?? 0,
      prizeName: json['prize_name'] ?? '',
      rewardAmount: double.tryParse('${json['reward_amount']}') ?? 0,
      rarity: (json['rarity'] as num?)?.toInt() ?? 0,
      isBigPrize: json['is_big_prize'] == true || json['is_big_prize'] == 1,
      cost: double.tryParse('${json['cost']}') ?? 0,
      balanceAfter: double.tryParse('${json['balance_after']}') ?? 0,
    );
  }

  bool get isWin => rewardAmount > 0;
}

/// 抽奖流水
class LotteryLogModel {
  final int id;
  final int prizeId;
  final String prizeName;
  final double cost;
  final double rewardAmount;
  final bool isBigPrize;
  final String createdAt;

  const LotteryLogModel({
    required this.id,
    this.prizeId = 0,
    this.prizeName = '',
    this.cost = 0,
    this.rewardAmount = 0,
    this.isBigPrize = false,
    this.createdAt = '',
  });

  factory LotteryLogModel.fromJson(Map<String, dynamic> json) {
    return LotteryLogModel(
      id: json['id'] ?? 0,
      prizeId: json['prize_id'] ?? 0,
      prizeName: json['prize_name'] ?? '',
      cost: double.tryParse('${json['cost']}') ?? 0,
      rewardAmount: double.tryParse('${json['reward_amount']}') ?? 0,
      isBigPrize: json['is_big_prize'] == true || json['is_big_prize'] == 1,
      createdAt: json['created_at'] ?? '',
    );
  }
}
