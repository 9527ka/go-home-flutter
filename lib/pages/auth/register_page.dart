import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';
import '../../widgets/eula_dialog.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _accountCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _agreeTerms = true; // 默认勾选协议
  int _accountType = 1; // 1=手机号 2=邮箱

  @override
  void dispose() {
    _accountCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_agreeTerms) {
      final l = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.get('agree_terms_required')),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final error = await auth.register(
      _accountCtrl.text.trim(),
      _passwordCtrl.text,
      _accountType,
    );

    if (!mounted) return;

    if (error == null) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (route) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppTheme.dangerColor),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l.get('register'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // 账号类型切换
              Row(
                children: [
                  ChoiceChip(
                    label: Text(l.get('phone')),
                    selected: _accountType == 1,
                    onSelected: (_) => setState(() => _accountType = 1),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(l.get('email')),
                    selected: _accountType == 2,
                    onSelected: (_) => setState(() => _accountType = 2),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 账号
              TextFormField(
                controller: _accountCtrl,
                keyboardType: _accountType == 1
                    ? TextInputType.phone
                    : TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: _accountType == 1 ? l.get('phone') : l.get('email'),
                  prefixIcon: Icon(
                    _accountType == 1 ? Icons.phone : Icons.email_outlined,
                  ),
                ),
                validator: _accountType == 1
                    ? Validators.phone
                    : Validators.email,
              ),

              const SizedBox(height: 16),

              // 密码
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: l.get('password_hint'),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                ),
                validator: Validators.password,
              ),

              const SizedBox(height: 16),

              // 确认密码
              TextFormField(
                controller: _confirmCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l.get('confirm_password'),
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
                validator: (value) {
                  if (value != _passwordCtrl.text) {
                    return l.get('password_mismatch');
                  }
                  return Validators.password(value);
                },
              ),

              const SizedBox(height: 20),

              // 用户协议勾选
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _agreeTerms,
                      onChanged: (v) => setState(() => _agreeTerms = v ?? true),
                      activeColor: AppTheme.primaryColor,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _agreeTerms = !_agreeTerms),
                      child: Text.rich(
                        TextSpan(
                          text: l.get('agree_terms_prefix'),
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          children: [
                            WidgetSpan(
                              alignment: PlaceholderAlignment.baseline,
                              baseline: TextBaseline.alphabetic,
                              child: GestureDetector(
                                onTap: () => EulaDialog.show(context),
                                child: Text(
                                  l.get('eula_link_text'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.primaryColor,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 注册按钮
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: auth.isLoading ? null : _register,
                  child: auth.isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(l.get('register'), style: const TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
