import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../utils/validators.dart';
import '../../widgets/eula_dialog.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _accountCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _agreeTerms = true; // 默认勾选协议
  bool _appleSignInLoading = false;
  bool _quickLoginLoading = false;

  @override
  void dispose() {
    _accountCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  /// 检查是否同意协议，未勾选时提示
  bool _checkTermsAgreed() {
    if (_agreeTerms) return true;
    final l = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.get('agree_terms_required')),
        backgroundColor: AppTheme.warningColor,
      ),
    );
    return false;
  }

  Future<void> _login() async {
    if (!_checkTermsAgreed()) return;
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final error = await auth.login(_accountCtrl.text.trim(), _passwordCtrl.text, rememberMe: _rememberMe);

    if (!mounted) return;
    if (error == null) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (route) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppTheme.dangerColor),
      );
    }
  }

  /// Apple 授权登录
  Future<void> _appleSignIn() async {
    if (!_checkTermsAgreed()) return;
    setState(() => _appleSignInLoading = true);

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      if (!mounted) return;

      final identityToken = credential.identityToken;
      final userIdentifier = credential.userIdentifier;

      if (identityToken == null || userIdentifier == null) {
        _showError('Apple 授权信息不完整');
        return;
      }

      // 拼接全名（Apple 仅首次授权返回名字）
      String? fullName;
      if (credential.givenName != null || credential.familyName != null) {
        fullName = [credential.familyName ?? '', credential.givenName ?? '']
            .where((s) => s.isNotEmpty)
            .join('');
      }

      final auth = context.read<AuthProvider>();
      final error = await auth.appleSignIn(
        identityToken: identityToken,
        userIdentifier: userIdentifier,
        fullName: fullName,
        email: credential.email,
      );

      if (!mounted) return;
      if (error == null) {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (route) => false);
      } else {
        _showError(error);
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        // 用户取消，不提示错误
        return;
      }
      if (mounted) _showError('Apple 授权失败');
    } catch (e) {
      if (mounted) _showError('Apple 登录异常，请重试');
    } finally {
      if (mounted) setState(() => _appleSignInLoading = false);
    }
  }

  /// 一键快速登录（游客模式）
  Future<void> _quickLogin() async {
    if (!_checkTermsAgreed()) return;
    setState(() => _quickLoginLoading = true);

    try {
      final auth = context.read<AuthProvider>();
      final error = await auth.quickLogin();

      if (!mounted) return;
      if (error == null) {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (route) => false);
      } else {
        _showError(error);
      }
    } catch (e) {
      if (mounted) _showError('快速登录异常，请重试');
    } finally {
      if (mounted) setState(() => _quickLoginLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.dangerColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 60),

                  // Logo + 标题区
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset('assets/icon/app_icon.png', width: 72, height: 72),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          l.get('welcome_back'),
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l.get('login_subtitle'),
                          style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 44),

                  // 账号输入
                  TextFormField(
                    controller: _accountCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: l.get('account_hint'),
                      prefixIcon: const Icon(Icons.person_outline, size: 22),
                    ),
                    validator: Validators.account,
                  ),

                  const SizedBox(height: 16),

                  // 密码输入
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: l.get('password_hint'),
                      prefixIcon: const Icon(Icons.lock_outline, size: 22),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 22,
                          color: AppTheme.textHint,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: Validators.password,
                  ),

                  const SizedBox(height: 16),

                  // 记住我
                  Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _rememberMe,
                          onChanged: (v) => setState(() => _rememberMe = v ?? true),
                          activeColor: AppTheme.primaryColor,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() => _rememberMe = !_rememberMe),
                        child: Text(
                          l.get('remember_me'),
                          style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

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

                  // 登录按钮
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: auth.isLoading ? null : _login,
                      child: auth.isLoading
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : Text(l.get('login')),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 注册入口
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(l.get('no_account'), style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, AppRoutes.register),
                        child: Text(
                          l.get('register_now'),
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 36),

                  // 分隔线
                  Row(
                    children: [
                      Expanded(child: Divider(color: AppTheme.dividerColor)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(l.get('or'), style: TextStyle(color: AppTheme.textHint, fontSize: 13)),
                      ),
                      Expanded(child: Divider(color: AppTheme.dividerColor)),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Apple 授权登录
                  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: _appleSignInLoading
                          ? const Center(
                              child: SizedBox(
                                width: 24, height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2.5),
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: _appleSignIn,
                              icon: const Icon(Icons.apple, size: 22),
                              label: Text(
                                l.get('apple_sign_in'),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 一键快速登录
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: _quickLoginLoading
                        ? const Center(
                            child: SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.5),
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: _quickLogin,
                            icon: const Icon(Icons.flash_on, size: 20),
                            label: Text(
                              l.get('quick_login'),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF34A853),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
        // 右上角语言切换按钮
        Positioned(
          top: 8,
          right: 8,
          child: _buildLanguageButton(context),
        ),
      ],
    ),
  ),
);
  }

  Widget _buildLanguageButton(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    final currentLocale = localeProvider.locale;
    final flag = _getFlag(currentLocale);

    return GestureDetector(
      onTap: () => _showLanguagePicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.scaffoldBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(flag, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 18, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    final localeProvider = context.read<LocaleProvider>();
    final currentLocale = localeProvider.locale;

    const languages = [
      (locale: Locale('zh', 'CN'), name: '简体中文', flag: '🇨🇳'),
      (locale: Locale('zh', 'TW'), name: '繁體中文', flag: '🇹🇼'),
      (locale: Locale('en', 'US'), name: 'English', flag: '🇺🇸'),
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: AppTheme.cardBg,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ...languages.map((lang) {
              final isSelected = currentLocale.languageCode == lang.locale.languageCode &&
                  currentLocale.countryCode == lang.locale.countryCode;
              return ListTile(
                leading: Text(lang.flag, style: const TextStyle(fontSize: 22)),
                title: Text(
                  lang.name,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: AppTheme.primaryColor, size: 22)
                    : null,
                onTap: () {
                  localeProvider.setLocale(lang.locale);
                  Navigator.pop(ctx);
                },
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  static String _getFlag(Locale locale) {
    switch ('${locale.languageCode}_${locale.countryCode}') {
      case 'zh_CN': return '🇨🇳';
      case 'zh_TW': return '🇹🇼';
      case 'en_US': return '🇺🇸';
      default: return '🌐';
    }
  }
}
