import '../config/api.dart';
import '../models/api_response.dart';
import '../models/lottery.dart';
import 'http_client.dart';

class LotteryService {
  final _http = HttpClient();

  Future<LotteryInfoModel?> getInfo() async {
    final res = await _http.get(ApiConfig.lotteryInfo);
    if (res['code'] == 0 && res['data'] != null) {
      return LotteryInfoModel.fromJson(res['data'] as Map<String, dynamic>);
    }
    return null;
  }

  /// 抽一次。返回服务端响应，业务层判 code。
  Future<Map<String, dynamic>> draw() async {
    return await _http.post(ApiConfig.lotteryDraw);
  }

  Future<PageData<LotteryLogModel>> getLogs({int page = 1}) async {
    final res = await _http.get(ApiConfig.lotteryLogs, params: {'page': page});
    if (res['code'] == 0 && res['data'] != null) {
      return PageData.fromJson(
        res['data'],
        (json) => LotteryLogModel.fromJson(json),
      );
    }
    return PageData(list: [], page: 1, pageSize: 20, total: 0);
  }
}
