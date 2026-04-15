import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/post_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/conversation_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/friend_provider.dart';
import '../../widgets/privacy_consent_dialog.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeIn;
  late Animation<double> _slideUp;
  bool _needsPrivacyConsent = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideUp = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
    );
    _animCtrl.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    final authProvider = context.read<AuthProvider>();

    // 并行：等待 Auth 初始化完成 + 最短动画展示时间（800ms）
    await Future.wait([
      _waitForAuth(authProvider),
      Future.delayed(const Duration(milliseconds: 800)),
    ]);

    if (!mounted) return;

    // 首次启动隐私协议弹窗
    final agreed = await PrivacyConsentDialog.hasAgreed();
    if (!agreed) {
      if (!mounted) return;
      final consent = await PrivacyConsentDialog.show(context);
      if (!consent) {
        // 用户拒绝，停留在启动页并显示提示
        if (mounted) setState(() => _needsPrivacyConsent = true);
        return;
      }
    }

    if (!mounted) return;
    _proceedToHome(authProvider);
  }

  void _proceedToHome(AuthProvider authProvider) {
    // 先从缓存加载文章列表（瞬间显示），再从 API 刷新
    final postProvider = context.read<PostProvider>();
    postProvider.loadFromCache();
    postProvider.refresh();

    // 仅登录用户才预加载需要鉴权的数据（游客调用会触发 401）
    if (authProvider.isLoggedIn) {
      context.read<ChatProvider>().checkUnread();
      context.read<NotificationProvider>().fetchUnreadCount();

      // 绑定 FriendProvider 到 ChatProvider（接收 WebSocket 好友通知）
      final friendProvider = context.read<FriendProvider>();
      friendProvider.bindChatProvider(context.read<ChatProvider>());
      friendProvider.bindConversationProvider(context.read<ConversationProvider>());
      friendProvider.fetchRequestCount();
    }

    // 跳转首页
    Navigator.pushReplacementNamed(context, AppRoutes.home);
  }

  /// 用户拒绝后，点击"重新查看"再次弹出隐私弹窗
  Future<void> _retryConsent() async {
    final consent = await PrivacyConsentDialog.show(context);
    if (consent && mounted) {
      setState(() => _needsPrivacyConsent = false);
      _proceedToHome(context.read<AuthProvider>());
    }
  }

  /// 等待 AuthProvider 初始化完成（最多等 2 秒，超时也跳转）
  Future<void> _waitForAuth(AuthProvider auth) async {
    if (auth.initialized) return;
    final completer = Completer<void>();
    void listener() {
      if (auth.initialized && !completer.isCompleted) {
        completer.complete();
        auth.removeListener(listener);
      }
    }
    auth.addListener(listener);
    // 超时保护：最多等 2 秒
    await completer.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () => auth.removeListener(listener),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF5BA0E8), Color(0xFF4A90D9), Color(0xFF2C5F8A)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: AnimatedBuilder(
              animation: _slideUp,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, _slideUp.value),
                child: child,
              ),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  // Logo
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset('assets/icon/app_icon.png', width: 110, height: 110),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    '回家了么',
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 2),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '帮助每一个走失的生命回家',
                    style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.85), letterSpacing: 1),
                  ),
                  const SizedBox(height: 48),
                  if (!_needsPrivacyConsent)
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white.withOpacity(0.7)),
                    ),
                  // 用户拒绝隐私协议后显示提示和重试按钮
                  if (_needsPrivacyConsent) ...[
                    Text(
                      AppLocalizations.of(context)?.get('privacy_dialog_disagree_msg') ?? '',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.85)),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _retryConsent,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(AppLocalizations.of(context)?.get('privacy_dialog_retry') ?? ''),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                    ),
                  ],
                  const Spacer(flex: 4),
                  // 底部分类展示
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _miniTag('宠物', AppTheme.petColor),
                            const SizedBox(width: 10),
                            _miniTag('亲人', AppTheme.elderColor),
                            const SizedBox(width: 10),
                            _miniTag('物品', AppTheme.otherColor),
                            const SizedBox(width: 10),
                            _aiTag(),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'AI 驱动 · 寻宠 · 寻亲',
                          style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.6), letterSpacing: 2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _aiTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF7C3AED).withOpacity(0.5), const Color(0xFF4A90D9).withOpacity(0.5)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 12, color: Colors.white),
          SizedBox(width: 4),
          Text('AI', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _miniTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
    );
  }
}
