/// 内容过滤工具 — Apple 审核要求 Guideline 1.2
/// 客户端侧基础敏感词过滤，服务端应做更完善的过滤
class ContentFilter {
  ContentFilter._();

  /// 敏感词列表（基础版，服务端应维护更完整的列表）
  static const List<String> _blockedKeywords = [
    // 色情相关
    '约炮', '一夜情', '裸聊', '色情', '成人视频', '援交',
    // 赌博相关
    '赌博', '博彩', '下注', '赔率', '开户送',
    // 诈骗相关
    '刷单', '兼职日结', '高额返利', '免费领取', '中奖了',
    // 违法相关
    '贩卖', '枪支', '毒品', '代开发票',
    // 广告垃圾
    '加微信', '加QQ', 'V信', '私聊有惊喜', '免费试用',
  ];

  /// 检查文本是否包含敏感词
  static bool containsBlockedContent(String text) {
    final lower = text.toLowerCase();
    for (final keyword in _blockedKeywords) {
      if (lower.contains(keyword.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  /// 过滤敏感词（替换为 ***）
  static String filter(String text) {
    var result = text;
    for (final keyword in _blockedKeywords) {
      result = result.replaceAll(
        RegExp(RegExp.escape(keyword), caseSensitive: false),
        '*' * keyword.length,
      );
    }
    return result;
  }
}
