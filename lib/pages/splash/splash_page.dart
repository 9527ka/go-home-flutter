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
import '../../services/http_client.dart';
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
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideUp = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
    );
    _animCtrl.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    final authProvider = context.read<AuthProvider>();

    // 不依赖 auth 的操作立即启动（与 auth 初始化并行）
    final agreedFuture = PrivacyConsentDialog.hasAgreed();
    final postProvider = context.read<PostProvider>();
    postProvider.loadFromCache(); // 从 SharedPreferences 读缓存，不需要 auth

    // 等待 auth 初始化（SharedPreferences 已预热，通常 <50ms）
    await _waitForAuth(authProvider);
    final agreed = await agreedFuture; // 已完成，秒返回

    if (!mounted) return;

    // 首次启动隐私协议弹窗
    if (!agreed) {
      final consent = await PrivacyConsentDialog.show(context);
      if (!consent) {
        if (mounted) setState(() => _needsPrivacyConsent = true);
        return;
      }
    }

    if (!mounted) return;
    _proceedToHome(authProvider);
  }

  void _proceedToHome(AuthProvider authProvider) {
    // 网络请求全部 fire-and-forget 并行发出
    context.read<PostProvider>().refresh();

    if (authProvider.isLoggedIn) {
      // 绑定 Provider（同步操作）
      final friendProvider = context.read<FriendProvider>();
      friendProvider.bindChatProvider(context.read<ChatProvider>());
      friendProvider.bindConversationProvider(context.read<ConversationProvider>());

      // 并行发起所有网络预加载
      context.read<ChatProvider>().checkUnread();
      context.read<NotificationProvider>().fetchUnreadCount();
      friendProvider.fetchRequestCount();
    }

    Navigator.pushReplacementNamed(context, AppRoutes.home);

    // 消费 Web 深链接：在 home 之上再推入目标详情页
    final pendingPostId = AppRoutes.pendingPostDetailId;
    if (pendingPostId != null) {
      AppRoutes.pendingPostDetailId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navigator = HttpClient.navigatorKey.currentState;
        navigator?.pushNamed(AppRoutes.postDetail, arguments: pendingPostId);
      });
    }
  }

  /// 用户拒绝后，点击"重新查看"再次弹出隐私弹窗
  Future<void> _retryConsent() async {
    final consent = await PrivacyConsentDialog.show(context);
    if (consent && mounted) {
      setState(() => _needsPrivacyConsent = false);
      _proceedToHome(context.read<AuthProvider>());
    }
  }

  /// 等待 AuthProvider 初始化完成
  /// SharedPreferences 已在 main() 预热，init 通常 <50ms；200ms 超时兜底
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
    await completer.future.timeout(
      const Duration(milliseconds: 200),
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
                  const SizedBox(height: 32),
                  if (!_needsPrivacyConsent) ...[
                    Text(
                      '欢迎回家',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.9)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '请稍候...',
                      style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.6)),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white.withOpacity(0.7)),
                    ),
                  ],
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
