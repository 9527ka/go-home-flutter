import 'package:flutter/material.dart';
import '../models/sign_status.dart';
import '../models/sign_result.dart';
import '../models/task_item.dart';
import '../services/sign_service.dart';

class SignProvider extends ChangeNotifier {
  final _service = SignInService();

  SignStatusModel? _status;
  SignResultModel? _lastSignResult;
  List<TaskItemModel> _tasks = [];
  bool _isLoading = false;
  bool _isSigning = false;
  bool _isLoadingTasks = false;

  SignStatusModel? get status => _status;
  SignResultModel? get lastSignResult => _lastSignResult;
  List<TaskItemModel> get tasks => _tasks;
  bool get isLoading => _isLoading;
  bool get isSigning => _isSigning;
  bool get isLoadingTasks => _isLoadingTasks;
  bool get signedToday => _status?.signedToday ?? false;
  int get currentStreak => _status?.currentStreak ?? 0;

  /// 加载签到状态
  Future<void> loadStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      _status = await _service.getStatus();
    } catch (e) {
      debugPrint('[SignProvider] loadStatus error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 执行签到
  Future<SignResultModel?> doSign() async {
    if (_isSigning) return null;

    _isSigning = true;
    notifyListeners();

    try {
      _lastSignResult = await _service.doSign();
      if (_lastSignResult != null) {
        // 更新本地状态
        await loadStatus();
      }
      return _lastSignResult;
    } catch (e) {
      debugPrint('[SignProvider] doSign error: $e');
      return null;
    } finally {
      _isSigning = false;
      notifyListeners();
    }
  }

  /// 加载任务列表
  Future<void> loadTasks() async {
    _isLoadingTasks = true;
    notifyListeners();

    try {
      _tasks = await _service.getTaskList();
    } catch (e) {
      debugPrint('[SignProvider] loadTasks error: $e');
    }

    _isLoadingTasks = false;
    notifyListeners();
  }

  /// 完成任务
  Future<bool> completeTask(String taskKey) async {
    try {
      final result = await _service.completeTask(taskKey);
      if (result != null) {
        // 刷新任务列表
        await loadTasks();
        return true;
      }
    } catch (e) {
      debugPrint('[SignProvider] completeTask error: $e');
    }
    return false;
  }

  /// 刷新全部数据
  Future<void> refresh() async {
    await Future.wait([loadStatus(), loadTasks()]);
  }
}
