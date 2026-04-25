import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/found_story_service.dart';

/// 标记已找到时的引导弹窗：
/// 1. 仅标记（不填故事）
/// 2. 填写找回故事（可选，奖励）
///
/// [rewardAmount] 服务端返回的当前配置奖励额（≤0 则不显示奖励文案）
class SubmitFoundStoryDialog extends StatefulWidget {
  final int postId;
  final double rewardAmount;

  const SubmitFoundStoryDialog({
    super.key,
    required this.postId,
    this.rewardAmount = 10,
  });

  /// 返回值：
  /// - null / false：用户取消
  /// - 'marked'：仅标记已找到
  /// - 'submitted'：已提交故事
  static Future<String?> show(BuildContext context, int postId, {double rewardAmount = 10}) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => SubmitFoundStoryDialog(postId: postId, rewardAmount: rewardAmount),
    );
  }

  @override
  State<SubmitFoundStoryDialog> createState() => _SubmitFoundStoryDialogState();
}

class _SubmitFoundStoryDialogState extends State<SubmitFoundStoryDialog> {
  final _service = FoundStoryService();
  final _controller = TextEditingController();
  bool _submitting = false;
  bool _showForm = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _markOnly() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final res = await _service.markFound(widget.postId);
    if (!mounted) return;
    if (res['code'] == 0) {
      Navigator.pop(context, 'marked');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['msg'] ?? '标记失败')));
      setState(() => _submitting = false);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final content = _controller.text.trim();
    if (content.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('找回经过至少 10 字')),
      );
      return;
    }
    setState(() => _submitting = true);
    final res = await _service.submit(postId: widget.postId, content: content);
    if (!mounted) return;
    if (res['code'] == 0) {
      Navigator.pop(context, 'submitted');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['msg'] ?? '提交失败')));
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: _showForm ? _buildForm() : _buildChoice(),
      ),
    );
  }

  Widget _buildChoice() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.celebration, size: 48, color: Color(0xFF10B981)),
        const SizedBox(height: 12),
        const Text(
          '恭喜找回！',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          widget.rewardAmount > 0
              ? '分享一下找回经过？帮助更多用户建立信任\n填写通过审核将奖励 ${widget.rewardAmount.toStringAsFixed(0)} 爱心币'
              : '分享一下找回经过？帮助更多用户建立信任',
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _submitting ? null : _markOnly,
                child: const Text('仅标记'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: _submitting ? null : () => setState(() => _showForm = true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('填写故事'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '分享找回经过',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          maxLines: 6,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: '讲讲找回过程，例如：线索来源、找回地点、感谢语等（至少 10 字）',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _submitting ? null : () => setState(() => _showForm = false),
                child: const Text('返回'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: _submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('提交'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
