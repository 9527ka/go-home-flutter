import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/routes.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/post_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/friend_provider.dart';
import 'providers/group_provider.dart';
import 'providers/conversation_provider.dart';
import 'providers/app_config_provider.dart';
import 'providers/wallet_provider.dart';
import 'providers/sign_provider.dart';
import 'providers/interaction_provider.dart';
import 'services/call_service.dart';
import 'services/http_client.dart';
import 'services/push_service.dart';
import 'utils/in_app_notifier.dart';
import 'l10n/app_localizations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // fire-and-forget 预热 SharedPreferences（不阻塞 runApp，provider 内首次 await 秒返回）
  SharedPreferences.getInstance();
  PushService.instance.init();

  // StoreKit1 配置延迟到 IapService 首次使用时执行（避免启动时加载 StoreKit 框架）

  runApp(const GoHomeApp());
}

class GoHomeApp extends StatelessWidget {
  const GoHomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => PostProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()..init()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => FriendProvider()),
        ChangeNotifierProvider(create: (_) => GroupProvider()),
        ChangeNotifierProvider(create: (_) => ConversationProvider()),
        ChangeNotifierProvider(create: (_) => AppConfigProvider()..fetchConfig()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProvider(create: (_) => SignProvider()),
        ChangeNotifierProvider(create: (_) => InteractionProvider()),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, _) {
          return MaterialApp(
            title: 'Go Home',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,

            // 绑定全局导航 Key（用于 Token 过期时跳转登录）
            navigatorKey: HttpClient.navigatorKey,
            // 绑定全局 ScaffoldMessenger Key（应用内消息横幅兜底，无需 context）
            scaffoldMessengerKey: InAppNotifier.scaffoldMessengerKey,

            // TUICallKit 需要监听路由以 push 来电/通话页（web stub 为空列表）
            navigatorObservers: CallService.instance.navigatorObservers,

            // 多语言（追加 TUICallKit 内置 AtomicLocalizations 以覆盖通话界面文案）
            localizationsDelegates: [
              const _AppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              ...CallService.instance.localizationsDelegates,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            locale: localeProvider.locale,

            // 路由
            initialRoute: AppRoutes.splash,
            routes: AppRoutes.routes,
            onGenerateRoute: AppRoutes.onGenerateRoute,
            onGenerateInitialRoutes: AppRoutes.onGenerateInitialRoutes,
          );
        },
      ),
    );
  }
}

/// 内联 Delegate — 确保 AppLocalizations 能通过 Localizations.of 获取
class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['zh', 'en'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate old) => true;
}
