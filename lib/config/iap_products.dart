/// Apple In-App Purchase 产品配置
class IapProducts {
  IapProducts._();

  /// 所有消耗型产品 ID
  static const Set<String> productIds = {
    'com.gohome.coin100',
    'com.gohome.coin500',
    'com.gohome.coin1000',
    'com.gohome.coin2000',
    'com.gohome.coin5000',
    'com.gohome.coin10000',
  };

  /// 产品 ID → 展示用爱心值数量（实际到账以服务端为准）
  static const Map<String, int> coinAmounts = {
    'com.gohome.coin100': 100,
    'com.gohome.coin500': 500,
    'com.gohome.coin1000': 1000,
    'com.gohome.coin2000': 2000,
    'com.gohome.coin5000': 5000,
    'com.gohome.coin10000': 10000,
  };

  /// 按爱心值从小到大排序的产品 ID 列表
  static List<String> get sortedProductIds {
    final list = productIds.toList();
    list.sort((a, b) => (coinAmounts[a] ?? 0).compareTo(coinAmounts[b] ?? 0));
    return list;
  }
}
