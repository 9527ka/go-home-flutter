import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

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
import 'services/call_signaling_service.dart';
import 'services/http_client.dart';
import 'services/push_service.dart';
import 'utils/in_app_notifier.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 强制 iOS 使用 StoreKit 1，让 IAP 收据为传统 base64（/verifyReceipt 可识别）。
  // 必须在任何 InAppPurchase.instance 访问之前、runApp 之前调用。
  // 注：plugin 已标记 deprecated，长期应改为服务端验证 StoreKit 2 JWS。
  if (Platform.isIOS) {
    // ignore: deprecated_member_use
    await InAppPurchaseStoreKitPlatform.enableStoreKit1();
  }

  PushService.instance.init();
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
        // 通话信令服务 —— 自动挂到 ChatProvider 的 WS，通话页用 Consumer 订阅
        ChangeNotifierProxyProvider<ChatProvider, CallSignalingService>(
          create: (_) => CallSignalingService.instance,
          update: (_, chat, call) {
            call!.attach(chat);
            return call;
          },
        ),
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

            // 多语言
            localizationsDelegates: const [
              _AppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            locale: localeProvider.locale,

            // 路由
            initialRoute: AppRoutes.splash,
            routes: AppRoutes.routes,
            onGenerateRoute: AppRoutes.onGenerateRoute,
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
