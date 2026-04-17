import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';

/// Bottom sheet dialog for changing or binding an account (phone/email).
class ChangeAccountDialog {
  /// Show the change account bottom sheet.
  ///
  /// [onSuccess] is called after the account is successfully changed,
  /// allowing the caller to refresh its own state if needed.
  static void show(BuildContext context, {VoidCallback? onSuccess}) {
    final l = AppLocalizations.of(context)!;
    final auth = context.read<AuthProvider>();
    final user = auth.user;

    final currentAccount = user?.account ?? '';
    final currentAccountType = (user?.accountType ?? 1);
    final accountCtrl = TextEditingController(text: currentAccount);
    int accountType = currentAccountType;
    String? errorText;
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
                  l.get('change_account'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),

                // Account type toggle
                Row(
                  children: [
                    _TypeChip(
                      label: l.get('phone'),
                      selected: accountType == 1,
                      onTap: () => setModalState(() {
                        accountType = 1;
                        errorText = null;
                      }),
                    ),
                    const SizedBox(width: 12),
                    _TypeChip(
                      label: l.get('email'),
                      selected: accountType == 2,
                      onTap: () => setModalState(() {
                        accountType = 2;
                        errorText = null;
                      }),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Input field
                TextField(
                  controller: accountCtrl,
                  keyboardType: accountType == 1
                      ? TextInputType.phone
                      : TextInputType.emailAddress,
                  onChanged: (_) {
                    if (errorText != null) {
                      setModalState(() => errorText = null);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: accountType == 1
                        ? l.get('phone_hint')
                        : l.get('email_hint'),
                    prefixIcon: Icon(
                      accountType == 1 ? Icons.phone_outlined : Icons.email_outlined,
                      size: 20,
                    ),
                    errorText: errorText,
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
                            final account = accountCtrl.text.trim();

                            final validationError = accountType == 1
                                ? Validators.phone(account)
                                : Validators.email(account);
                            if (validationError != null) {
                              setModalState(() => errorText = validationError);
                              return;
                            }

                            setModalState(() => isSaving = true);

                            final error = await auth.changeAccount(account, accountType);
                            if (!context.mounted) return;

                            setModalState(() => isSaving = false);

                            if (error == null) {
                              final messenger = ScaffoldMessenger.of(context);
                              Navigator.pop(ctx);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(l.get('account_change_success')),
                                  backgroundColor: AppTheme.successColor,
                                ),
                              );
                              onSuccess?.call();
                            } else {
                              setModalState(() => errorText = error);
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

/// Account type selection chip.
class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primaryColor : AppTheme.dividerColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
