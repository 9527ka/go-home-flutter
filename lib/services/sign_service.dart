import '../config/api.dart';
import '../models/sign_status.dart';
import '../models/sign_result.dart';
import '../models/task_item.dart';
import 'http_client.dart';

class SignInService {
  final _http = HttpClient();

  /// 获取签到状态
  Future<SignStatusModel?> getStatus() async {
    final res = await _http.get(ApiConfig.signStatus);
    if (res['code'] == 0 && res['data'] != null) {
      return SignStatusModel.fromJson(res['data']);
    }
    return null;
  }

  /// 执行签到
  Future<SignResultModel?> doSign() async {
    final res = await _http.post(ApiConfig.signIn);
    if (res['code'] == 0 && res['data'] != null) {
      return SignResultModel.fromJson(res['data']);
    }
    return null;
  }

  /// 获取任务列表
  Future<List<TaskItemModel>> getTaskList() async {
    final res = await _http.get(ApiConfig.taskList);
    if (res['code'] == 0 && res['data'] != null) {
      return (res['data'] as List<dynamic>)
          .map((e) => TaskItemModel.fromJson(e))
          .toList();
    }
    return [];
  }

  /// 完成任务
  Future<Map<String, dynamic>?> completeTask(String taskKey) async {
    final res = await _http.post(ApiConfig.taskComplete, data: {
      'task_key': taskKey,
    });
    if (res['code'] == 0 && res['data'] != null) {
      return Map<String, dynamic>.from(res['data']);
    }
    return null;
  }
}
