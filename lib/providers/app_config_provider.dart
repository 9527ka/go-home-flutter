import 'package:flutter/material.dart';
import '../config/api.dart';
import '../services/http_client.dart';

/// 分类配置项
class CategoryConfig {
  final int id;
  final String name;
  final String icon;

  CategoryConfig({required this.id, required this.name, required this.icon});

  factory CategoryConfig.fromJson(Map<String, dynamic> json) {
    return CategoryConfig(
      id: json['id'] as int,
      name: json['name'] as String,
      icon: json['icon'] as String? ?? '',
    );
  }
}

/// App 配置 Provider — 从服务端获取可见分类等配置
class AppConfigProvider extends ChangeNotifier {
  final _http = HttpClient();

  /// 默认可见分类（未加载时的 fallback，与服务端保持一致）
  static const _defaultVisible = [1, 4]; // 宠物 + 物品

  List<CategoryConfig> _visibleCategories = [];
  bool _isLoaded = false;
  bool _walletEnabled = false;
  double _boostHourlyRate = 10;
  bool _bannerEnabled = false;
  String _bannerText = '';
  String _bannerLink = '';
  Map<String, String> _about = {};

  List<CategoryConfig> get visibleCategories => _visibleCategories;
  bool get isLoaded => _isLoaded;
  bool get walletEnabled => _walletEnabled;
  double get boostHourlyRate => _boostHourlyRate;
  bool get bannerEnabled => _bannerEnabled;
  String get bannerText => _bannerText;
  String get bannerLink => _bannerLink;
  Map<String, String> get about => _about;

  /// 检查某个分类是否可见
  bool isCategoryVisible(int categoryId) {
    if (!_isLoaded) return _defaultVisible.contains(categoryId);
    return _visibleCategories.any((c) => c.id == categoryId);
  }

  /// 从服务端加载配置
  Future<void> fetchConfig() async {
    try {
      final res = await _http.get(ApiConfig.configApp);
      debugPrint('[AppConfig] fetchConfig response code=${res['code']}');
      if (res['code'] == 0 && res['data'] != null) {
        final data = res['data'] as Map<String, dynamic>;
        final list = data['visible_categories'] as List? ?? [];
        _visibleCategories = list
            .map((e) => CategoryConfig.fromJson(e as Map<String, dynamic>))
            .toList();
        _walletEnabled = data['wallet_enabled'] == true;
        _boostHourlyRate = (data['boost_hourly_rate'] ?? 10).toDouble();
        _bannerEnabled = data['banner_enabled'] == true;
        _bannerText = (data['banner_text'] as String?) ?? '';
        _bannerLink = (data['banner_link'] as String?) ?? '';
        final aboutData = data['about'] as Map<String, dynamic>? ?? {};
        _about = aboutData.map((k, v) => MapEntry(k, v?.toString() ?? ''));
        _isLoaded = true;
        debugPrint('[AppConfig] walletEnabled=$_walletEnabled, boostRate=$_boostHourlyRate, bannerEnabled=$_bannerEnabled');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[AppConfig] fetchConfig error: $e');
    }
  }
}
