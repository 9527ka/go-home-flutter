import '../config/api.dart';
import '../models/api_response.dart';
import '../models/vip.dart';
import 'http_client.dart';

class VipService {
  final _http = HttpClient();

  /// 获取所有 VIP 等级配置
  Future<List<VipLevelModel>> getLevels() async {
    final res = await _http.get(ApiConfig.vipLevels);
    if (res['code'] == 0 && res['data'] is List) {
      return (res['data'] as List)
          .map((e) => VipLevelModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return const [];
  }

  /// 我的 VIP 状态
  Future<MyVipModel?> getMy() async {
    final res = await _http.get(ApiConfig.vipMy);
    if (res['code'] == 0 && res['data'] != null) {
      return MyVipModel.fromJson(res['data'] as Map<String, dynamic>);
    }
    return null;
  }

  /// 购买/续费 VIP
  /// 返回服务端原始响应，业务层根据 code 判断
  Future<Map<String, dynamic>> purchase(String levelKey) async {
    return await _http.post(ApiConfig.vipPurchase, data: {
      'level_key': levelKey,
    });
  }

  /// 我的购买记录
  Future<PageData<VipOrderModel>> getOrders({int page = 1}) async {
    final res = await _http.get(ApiConfig.vipOrders, params: {'page': page});
    if (res['code'] == 0 && res['data'] != null) {
      return PageData.fromJson(
        res['data'],
        (json) => VipOrderModel.fromJson(json),
      );
    }
    return PageData(list: [], page: 1, pageSize: 20, total: 0);
  }
}
