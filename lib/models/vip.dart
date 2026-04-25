/// VIP 等级配置
class VipLevelModel {
  final String levelKey;
  final String levelName;
  final int levelOrder;
  final double price;
  final int durationDays;
  final double signBonusRate;
  final double critProbBonus;
  final int critMaxMultiple;
  final double withdrawFeeRate;
  final double withdrawDailyLimit;
  final String iconUrl;
  final String badgeEffectKey;
  final String nameEffectKey;
  final String redPacketSkinUrl;
  final String redPacketEffectKey;

  const VipLevelModel({
    required this.levelKey,
    required this.levelName,
    required this.levelOrder,
    this.price = 0,
    this.durationDays = 30,
    this.signBonusRate = 0,
    this.critProbBonus = 0,
    this.critMaxMultiple = 5,
    this.withdrawFeeRate = 0.3,
    this.withdrawDailyLimit = 1000,
    this.iconUrl = '',
    this.badgeEffectKey = 'none',
    this.nameEffectKey = 'none',
    this.redPacketSkinUrl = '',
    this.redPacketEffectKey = 'none',
  });

  factory VipLevelModel.fromJson(Map<String, dynamic> json) {
    return VipLevelModel(
      levelKey: json['level_key'] ?? 'normal',
      levelName: json['level_name'] ?? '普通',
      levelOrder: (json['level_order'] as num?)?.toInt() ?? 1,
      price: double.tryParse('${json['price']}') ?? 0,
      durationDays: (json['duration_days'] as num?)?.toInt() ?? 30,
      signBonusRate: double.tryParse('${json['sign_bonus_rate']}') ?? 0,
      critProbBonus: double.tryParse('${json['crit_prob_bonus']}') ?? 0,
      critMaxMultiple: (json['crit_max_multiple'] as num?)?.toInt() ?? 5,
      withdrawFeeRate: double.tryParse('${json['withdraw_fee_rate']}') ?? 0.3,
      withdrawDailyLimit:
          double.tryParse('${json['withdraw_daily_limit']}') ?? 1000,
      iconUrl: json['icon_url'] ?? '',
      badgeEffectKey: json['badge_effect_key'] ?? 'none',
      nameEffectKey: json['name_effect_key'] ?? 'none',
      redPacketSkinUrl: json['red_packet_skin_url'] ?? '',
      redPacketEffectKey: json['red_packet_effect_key'] ?? 'none',
    );
  }

  bool get isNormal => levelKey == 'normal';
}

/// 我的 VIP 状态
class MyVipModel {
  final VipLevelModel level;
  final String? expiredAt; // 到期时间(ISO string)
  final bool isActive;

  const MyVipModel({
    required this.level,
    this.expiredAt,
    this.isActive = false,
  });

  factory MyVipModel.fromJson(Map<String, dynamic> json) {
    return MyVipModel(
      level: VipLevelModel.fromJson(json['level'] ?? {}),
      expiredAt: json['expired_at'],
      isActive: json['is_active'] ?? false,
    );
  }
}

/// 嵌入到 user 对象中的 VIP 快照（随各列表/详情接口返回）
/// 普通用户返回 null（后端规则：未在有效期则 vip = null）
class VipBadgeModel {
  final String levelKey;
  final String levelName;
  final int levelOrder;
  final String badgeEffectKey;
  final String nameEffectKey;
  final String iconUrl;
  final String? expiredAt;

  const VipBadgeModel({
    required this.levelKey,
    required this.levelName,
    required this.levelOrder,
    this.badgeEffectKey = 'none',
    this.nameEffectKey = 'none',
    this.iconUrl = '',
    this.expiredAt,
  });

  factory VipBadgeModel.fromJson(Map<String, dynamic> json) {
    return VipBadgeModel(
      levelKey: json['level_key'] ?? 'normal',
      levelName: json['level_name'] ?? '普通',
      levelOrder: (json['level_order'] as num?)?.toInt() ?? 1,
      badgeEffectKey: json['badge_effect_key'] ?? 'none',
      nameEffectKey: json['name_effect_key'] ?? 'none',
      iconUrl: json['icon_url'] ?? '',
      expiredAt: json['expired_at'],
    );
  }

  /// 从任意对象中安全解析 vip 字段
  static VipBadgeModel? tryParse(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return VipBadgeModel.fromJson(raw);
    }
    return null;
  }

  bool get isNormal => levelKey == 'normal';
}

/// VIP 购买订单
class VipOrderModel {
  final int id;
  final int userId;
  final String levelKey;
  final double price;
  final int durationDays;
  final String? prevExpiredAt;
  final String newExpiredAt;
  final int status;
  final String createdAt;

  const VipOrderModel({
    required this.id,
    required this.userId,
    required this.levelKey,
    required this.price,
    required this.durationDays,
    this.prevExpiredAt,
    required this.newExpiredAt,
    this.status = 1,
    required this.createdAt,
  });

  factory VipOrderModel.fromJson(Map<String, dynamic> json) {
    return VipOrderModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      levelKey: json['level_key'] ?? '',
      price: double.tryParse('${json['price']}') ?? 0,
      durationDays: (json['duration_days'] as num?)?.toInt() ?? 0,
      prevExpiredAt: json['prev_expired_at'],
      newExpiredAt: json['new_expired_at'] ?? '',
      status: json['status'] ?? 1,
      createdAt: json['created_at'] ?? '',
    );
  }
}
