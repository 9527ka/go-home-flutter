import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';

/// Bottom sheet dialog for changing or setting a password.
class ChangePasswordDialog {
  /// Show the change password bottom sheet.
  ///
  /// [needOldPassword] determines whether the old password field is shown
  /// (false for guest/Apple users setting a password for the first time).
  static void show(BuildContext context, {required bool needOldPassword}) {
    final l = AppLocalizations.of(context)!;
    final auth = context.read<AuthProvider>();

    final oldPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  needOldPassword ? l.get('change_password') : l.get('set_password'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),

                // Old password (only for regular users)
                if (needOldPassword) ...[
                  TextField(
                    controller: oldPasswordCtrl,
                    obscureText: obscureOld,
                    decoration: InputDecoration(
                      hintText: l.get('old_password_hint'),
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureOld ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 20,
                          color: AppTheme.textHint,
                        ),
                        onPressed: () => setModalState(() => obscureOld = !obscureOld),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // New password
                TextField(
                  controller: newPasswordCtrl,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    hintText: l.get('new_password_hint'),
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20,
                        color: AppTheme.textHint,
                      ),
                      onPressed: () => setModalState(() => obscureNew = !obscureNew),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Confirm new password
                TextField(
                  controller: confirmPasswordCtrl,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    hintText: l.get('confirm_new_password_hint'),
                    prefixIcon: const Icon(Icons.lock_outline, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 20,
                        color: AppTheme.textHint,
                      ),
                      onPressed: () => setModalState(() => obscureConfirm = !obscureConfirm),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final newPwd = newPasswordCtrl.text;
                            final confirmPwd = confirmPasswordCtrl.text;

                            if (newPwd.isEmpty) {
                              Fluttertoast.showToast(msg: l.get('password_empty'));
                              return;
                            }
                            if (newPwd.length < 6) {
                              Fluttertoast.showToast(msg: l.get('password_too_short'));
                              return;
                            }
                            if (newPwd != confirmPwd) {
                              Fluttertoast.showToast(msg: l.get('password_mismatch'));
                              return;
                            }

                            setModalState(() => isSaving = true);

                            final error = await auth.changePassword(
                              oldPassword: needOldPassword ? oldPasswordCtrl.text : null,
                              newPassword: newPwd,
                            );

                            if (!context.mounted) return;

                            setModalState(() => isSaving = false);

                            if (error == null) {
                              final messenger = ScaffoldMessenger.of(context);
                              Navigator.pop(ctx);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(l.get('password_change_success')),
                                  backgroundColor: AppTheme.successColor,
                                ),
                              );
                            } else {
                              Fluttertoast.showToast(msg: error);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : Text(l.get('save'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
