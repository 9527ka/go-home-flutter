import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/http_client.dart';
import '../config/api.dart';

class ReportDialog extends StatefulWidget {
  final int targetType; // 1=启事 2=线索 3=用户
  final int targetId;

  const ReportDialog({
    super.key,
    required this.targetType,
    required this.targetId,
  });

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  int? _reason;
  final _descCtrl = TextEditingController();
  bool _isSubmitting = false;

  final _reasons = {
    1: '虚假信息',
    2: '广告推销',
    3: '涉及违法',
    4: '骚扰辱骂',
    5: '其他',
  };

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_reason == null) return;

    setState(() => _isSubmitting = true);

    try {
      final res = await HttpClient().post(ApiConfig.reportCreate, data: {
        'target_type': widget.targetType,
        'target_id': widget.targetId,
        'reason': _reason,
        'description': _descCtrl.text.trim(),
      });

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);

      messenger.showSnackBar(
        SnackBar(
          content: Text(res['code'] == 0 ? '举报已提交' : (res['msg'] ?? '举报失败')),
          backgroundColor: res['code'] == 0 ? AppTheme.successColor : AppTheme.dangerColor,
        ),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('举报'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('请选择举报原因：'),
            const SizedBox(height: 8),
            ..._reasons.entries.map((e) {
              return RadioListTile<int>(
                contentPadding: EdgeInsets.zero,
                title: Text(e.value, style: const TextStyle(fontSize: 14)),
                value: e.key,
                groupValue: _reason,
                onChanged: (v) => setState(() => _reason = v),
              );
            }),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: '补充说明（可选）',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _reason == null || _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('提交'),
        ),
      ],
    );
  }
}
