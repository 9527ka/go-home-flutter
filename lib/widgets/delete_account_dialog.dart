import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/routes.dart';
import '../config/theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../utils/session_reset.dart';

class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key});

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _passwordCtrl = TextEditingController();
  bool _isSubmitting = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) return;

    final l = AppLocalizations.of(context)!;
    final isAppleUser = user.authProvider == 2;

    // 普通用户需要输入密码
    if (!isAppleUser && _passwordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.get('enter_password_to_confirm')),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    String? error;
    if (isAppleUser) {
      error = await auth.deleteAccount(confirm: true);
    } else {
      error = await auth.deleteAccount(password: _passwordCtrl.text);
    }

    if (!mounted) return;

    if (error == null) {
      // 先获取 SnackBar 的 messenger，避免导航后 context 失效
      final messenger = ScaffoldMessenger.of(context);
      // 注销账号成功后，彻底清理 Provider 内存 + per-user prefs，防止残留
      await performLogout(context, isDeleteAccount: true);
      if (!mounted) return;
      Navigator.pop(context); // close dialog
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.home,
        (route) => false,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(l.get('account_deleted_success')),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } else {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final auth = context.watch<AuthProvider>();
    final isAppleUser = auth.user?.authProvider == 2;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.dangerColor, size: 24),
          const SizedBox(width: 8),
          Text(l.get('delete_account')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.get('delete_account_warning'),
              style: const TextStyle(fontSize: 14, color: AppTheme.dangerColor),
            ),
            const SizedBox(height: 20),
            if (isAppleUser != true) ...[
              Text(
                l.get('enter_password_to_confirm'),
                style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: l.get('password_hint'),
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: AppTheme.textHint,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ] else ...[
              Text(
                l.get('apple_delete_confirm'),
                style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.get('cancel')),
        ),
        TextButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  l.get('confirm_delete'),
                  style: const TextStyle(color: AppTheme.dangerColor),
                ),
        ),
      ],
    );
  }
}
