import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/currency.dart';
import '../../config/theme.dart';
import '../../models/sign_result.dart';
import '../../models/task_item.dart';
import '../../providers/sign_provider.dart';
import '../../widgets/sign_reward_dialog.dart';

class SignPage extends StatefulWidget {
  const SignPage({super.key});

  @override
  State<SignPage> createState() => _SignPageState();
}

class _SignPageState extends State<SignPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SignProvider>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('签到中心')),
      body: Consumer<SignProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.status == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: provider.refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSignCard(context, provider),
                const SizedBox(height: 16),
                _buildTaskSection(context, provider),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 签到卡片：7天网格 + 签到按钮
  Widget _buildSignCard(BuildContext context, SignProvider provider) {
    final status = provider.status;
    final rewards = status?.rewardsConfig ?? [0.1, 0.2, 0.3, 0.5, 0.8, 1, 2];
    final weekStatus = status?.weekStatus ?? List.filled(7, false);
    final signedToday = status?.signedToday ?? false;
    final currentStreak = status?.currentStreak ?? 0;
    final dayInCycle = status?.dayInCycle ?? 1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4A90D9), Color(0xFF6BB5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '每日签到',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  signedToday
                      ? '已连续签到 $currentStreak 天'
                      : currentStreak > 0
                          ? '已连续 $currentStreak 天'
                          : '开始签到吧',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 7天奖励网格
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final isCompleted = index < weekStatus.length && weekStatus[index];
              final isToday = index == dayInCycle - 1;
              final reward = index < rewards.length ? rewards[index] : 0.0;

              return _buildDayItem(
                day: index + 1,
                reward: reward,
                isCompleted: isCompleted,
                isToday: isToday && !signedToday,
              );
            }),
          ),
          const SizedBox(height: 20),

          // 签到按钮
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: signedToday || provider.isSigning
                  ? null
                  : () => _handleSign(context, provider),
              style: ElevatedButton.styleFrom(
                backgroundColor: signedToday
                    ? Colors.white.withOpacity(0.3)
                    : Colors.white,
                foregroundColor: signedToday
                    ? Colors.white70
                    : AppTheme.primaryColor,
                disabledBackgroundColor: Colors.white.withOpacity(0.3),
                disabledForegroundColor: Colors.white70,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: provider.isSigning
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      signedToday ? '今日已签到' : '立即签到',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// 单天奖励项
  Widget _buildDayItem({
    required int day,
    required double reward,
    required bool isCompleted,
    required bool isToday,
  }) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isCompleted
                ? Colors.white
                : isToday
                    ? Colors.white.withOpacity(0.3)
                    : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: isToday
                ? Border.all(color: Colors.white, width: 2)
                : null,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: AppTheme.successColor, size: 20)
                : Text(
                    '+${CurrencyConfig.formatNumber(reward)}',
                    style: TextStyle(
                      color: isToday ? Colors.white : Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '第$day天',
          style: TextStyle(
            color: isCompleted ? Colors.white : Colors.white70,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  /// 任务列表区域
  Widget _buildTaskSection(BuildContext context, SignProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            '每日任务',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        if (provider.isLoadingTasks && provider.tasks.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (provider.tasks.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                '暂无可用任务',
                style: TextStyle(color: AppTheme.textHint),
              ),
            ),
          )
        else
          ...provider.tasks.map((task) => _buildTaskItem(context, provider, task)),
      ],
    );
  }

  /// 单个任务卡片
  Widget _buildTaskItem(BuildContext context, SignProvider provider, TaskItemModel task) {
    final isDone = task.isRewarded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          // 任务图标
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDone
                  ? AppTheme.successColor.withOpacity(0.1)
                  : AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getTaskIcon(task.taskKey),
              color: isDone ? AppTheme.successColor : AppTheme.primaryColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),

          // 任务信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  task.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (task.targetCount > 1) ...[
                  const SizedBox(height: 6),
                  // 进度条
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: task.progressPercent,
                      backgroundColor: AppTheme.dividerColor,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDone ? AppTheme.successColor : AppTheme.primaryColor,
                      ),
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${task.progress}/${task.targetCount}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textHint,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),

          // 奖励 + 按钮
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${CurrencyConfig.formatNumber(task.reward)} ${CurrencyConfig.coinUnit}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDone ? AppTheme.textHint : AppTheme.accentColor,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 30,
                child: isDone
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Center(
                          child: Text(
                            '已完成',
                            style: TextStyle(
                              color: AppTheme.successColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      )
                    : task.isCompleted
                        ? ElevatedButton(
                            onPressed: () => _handleCompleteTask(context, provider, task.taskKey),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentColor,
                              foregroundColor: Colors.white,
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 0,
                            ),
                            child: const Text('领取', style: TextStyle(fontSize: 12)),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.scaffoldBg,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Center(
                              child: Text(
                                '进行中',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 签到操作
  Future<void> _handleSign(BuildContext context, SignProvider provider) async {
    final result = await provider.doSign();
    if (result != null && mounted) {
      showDialog(
        context: context,
        builder: (_) => SignRewardDialog(result: result),
      );
    }
  }

  /// 领取任务奖励
  Future<void> _handleCompleteTask(
    BuildContext context,
    SignProvider provider,
    String taskKey,
  ) async {
    final success = await provider.completeTask(taskKey);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('任务奖励已发放到待释放爱心值')),
      );
    }
  }

  /// 根据任务类型返回图标
  IconData _getTaskIcon(String taskKey) {
    switch (taskKey) {
      case 'login':
        return Icons.login;
      case 'chat_3':
        return Icons.chat_bubble_outline;
      case 'complete_profile':
        return Icons.person_outline;
      case 'purchase':
        return Icons.shopping_cart_outlined;
      case 'invite':
        return Icons.person_add_outlined;
      default:
        return Icons.task_alt;
    }
  }
}
