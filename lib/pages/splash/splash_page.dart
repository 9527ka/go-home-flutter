import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/post_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/eula_dialog.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeIn;
  late Animation<double> _slideUp;

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

    // EULA 检查：首次使用必须同意用户协议（Apple Guideline 1.2）
    final eulaAccepted = await EulaDialog.checkAndShow(context);
    if (!eulaAccepted) {
      // 用户拒绝，停留在 Splash 并再次弹出
      if (mounted) _navigate();
      return;
    }

    if (!mounted) return;

    // Auth 就绪后，提前预加载首页数据（不阻塞跳转）
    context.read<PostProvider>().refresh();
    context.read<ChatProvider>().checkUnread();
    context.read<NotificationProvider>().fetchUnreadCount();

    // 跳转首页
    Navigator.pushReplacementNamed(context, AppRoutes.home);
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: const Icon(Icons.home_rounded, size: 60, color: AppTheme.primaryColor),
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
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white.withOpacity(0.7)),
                  ),
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
                            const SizedBox(width: 12),
                            _miniTag('成年人', AppTheme.elderColor),
                            const SizedBox(width: 12),
                            _miniTag('儿童', AppTheme.childColor),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '寻宠 · 寻亲 · 寻人',
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
