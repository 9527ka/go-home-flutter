/// 任务项
class TaskItemModel {
  final String taskKey;
  final String name;
  final String description;
  final double reward;
  final int targetCount;
  final int progress;
  final bool isCompleted;
  final bool isRewarded;

  TaskItemModel({
    required this.taskKey,
    required this.name,
    this.description = '',
    this.reward = 0,
    this.targetCount = 1,
    this.progress = 0,
    this.isCompleted = false,
    this.isRewarded = false,
  });

  factory TaskItemModel.fromJson(Map<String, dynamic> json) {
    return TaskItemModel(
      taskKey: json['task_key'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      reward: double.tryParse('${json['reward']}') ?? 0,
      targetCount: json['target_count'] ?? 1,
      progress: json['progress'] ?? 0,
      isCompleted: json['is_completed'] ?? false,
      isRewarded: json['is_rewarded'] ?? false,
    );
  }

  /// 进度百分比 0.0 ~ 1.0
  double get progressPercent =>
      targetCount > 0 ? (progress / targetCount).clamp(0.0, 1.0) : 0.0;
}
