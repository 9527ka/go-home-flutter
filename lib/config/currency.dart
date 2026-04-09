/// 爱心值配置
///
/// 系统内部所有数值均以「爱心值」为单位。
/// 获取/发放时按汇率与 USDT 互换。
class CurrencyConfig {
  CurrencyConfig._();

  /// 币种名称
  static const String coinName = '爱心值';

  /// 币种文本符号（纯文本场景的 fallback，主要展示请用 CoinIcon/CoinAmount 组件）
  static const String coinSymbol = '¤';

  /// 单位（用于数值后缀，如 "100 爱心值"）
  static const String coinUnit = '爱心值';

  /// 汇率：1 USDT = ? 爱心值
  static const double ratePerUsdt = 100;

  /// USDT → 爱心值
  static double fromUsdt(double usdt) => usdt * ratePerUsdt;

  /// 爱心值 → USDT
  static double toUsdt(double coins) => coins / ratePerUsdt;

  /// 格式化爱心值数量（整数显示，不带小数）
  static String format(double amount) {
    if (amount == amount.roundToDouble()) {
      return '${amount.toInt()}';
    }
    return amount.toStringAsFixed(1);
  }

  /// 格式化爱心值数量（纯数字，不带符号）— 与 format 一致
  static String formatNumber(double amount) => format(amount);

  /// 格式化爱心值数量（带单位后缀）
  static String formatWithUnit(double amount) {
    return '${format(amount)} $coinUnit';
  }

  /// 带正负号的显示数量（用于明细）
  static String formatSigned(double amount, {required bool isIncome}) {
    final prefix = isIncome ? '+' : '-';
    return '$prefix${format(amount)}';
  }
}
