import '../config/api.dart';

/// URL 工具类 — 处理相对/绝对路径转换
class UrlHelper {
  UrlHelper._();

  /// 确保 URL 为绝对路径
  /// 如果传入的是相对路径（以 / 开头但不以 http 开头），自动拼接 API baseUrl
  /// 空字符串或 null 返回空字符串
  static String ensureAbsolute(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    // 系统头像等相对路径保持原样（不应当作网络图片加载）
    if (url.startsWith('/system/')) return url;
    // 其他相对路径拼接 baseUrl
    final base = ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
        : ApiConfig.baseUrl;
    final path = url.startsWith('/') ? url : '/$url';
    return '$base$path';
  }

  /// 判断是否为有效的可播放/可加载网络 URL
  static bool isValidNetworkUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }
}
