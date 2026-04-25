import 'package:flutter/material.dart';
import '../models/post.dart';
import '../pages/splash/splash_page.dart';
import '../pages/auth/login_page.dart';
import '../pages/auth/register_page.dart';
import '../pages/home/home_page.dart';
import '../pages/post/post_create_page.dart';
import '../pages/post/post_detail_page.dart';
import '../pages/post/post_edit_page.dart';
import '../pages/post/post_search_page.dart';
import '../pages/profile/profile_page.dart';
import '../pages/profile/my_posts_page.dart';
import '../pages/profile/favorites_page.dart';
import '../pages/profile/notifications_page.dart';
import '../pages/profile/about_page.dart';
import '../pages/profile/language_page.dart';
import '../pages/profile/edit_profile_page.dart';
import '../pages/profile/feedback_page.dart';
import '../pages/profile/account_settings_page.dart';
import '../pages/chat/conversation_list_page.dart';
import '../pages/chat/private_chat_page.dart';
import '../pages/friend/friend_list_page.dart';
import '../pages/friend/friend_request_page.dart';
import '../pages/friend/friend_search_page.dart';
import '../pages/group/group_create_page.dart';
import '../pages/group/group_chat_page.dart';
import '../pages/group/group_detail_page.dart';
import '../pages/wallet/wallet_page.dart';
import '../pages/wallet/recharge_page.dart';
import '../pages/wallet/withdraw_page.dart';
import '../pages/wallet/transaction_history_page.dart';
import '../pages/wallet/red_packet_detail_page.dart';
import '../pages/sign/sign_page.dart';
import '../pages/lottery/lottery_page.dart';
import '../pages/vip/vip_center_page.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String postCreate = '/post/create';
  static const String postDetail = '/post/detail';
  static const String postEdit = '/post/edit';
  static const String postSearch = '/post/search';
  static const String profile = '/profile';
  static const String myPosts = '/my-posts';
  static const String favorites = '/favorites';
  static const String notifications = '/notifications';
  static const String about = '/about';
  static const String language = '/language';
  static const String editProfile = '/edit-profile';
  static const String feedback = '/feedback';
  static const String accountSettings = '/account-settings';
  static const String conversations = '/conversations';
  static const String privateChat = '/private-chat';

  // 好友相关路由
  static const String friendListPage = '/friends';
  static const String friendRequests = '/friend-requests';
  static const String friendSearch = '/friend-search';

  // 群组
  static const String groupCreate = '/group/create';
  static const String groupChat = '/group/chat';
  static const String groupDetail = '/group/detail';

  // 签到
  static const String signIn = '/sign-in';

  // 爱心中心
  static const String wallet = '/wallet';
  static const String walletRecharge = '/wallet/recharge';
  static const String walletWithdraw = '/wallet/withdraw';
  static const String walletTransactions = '/wallet/transactions';
  static const String redPacketDetail = '/red-packet/detail';

  // 抽奖
  static const String lottery = '/lottery';

  // VIP
  static const String vipCenter = '/vip';

  static Map<String, WidgetBuilder> get routes => {
        splash: (_) => const SplashPage(),
        login: (_) => const LoginPage(),
        register: (_) => const RegisterPage(),
        home: (_) => const HomePage(),
        postCreate: (_) => const PostCreatePage(),
        postSearch: (_) => const PostSearchPage(),
        profile: (_) => const ProfilePage(),
        myPosts: (_) => const MyPostsPage(),
        favorites: (_) => const FavoritesPage(),
        notifications: (_) => const NotificationsPage(),
        about: (_) => const AboutPage(),
        language: (_) => const LanguagePage(),
        editProfile: (_) => const EditProfilePage(),
        feedback: (_) => const FeedbackPage(),
        accountSettings: (_) => const AccountSettingsPage(),
        conversations: (_) => const ConversationListPage(),
        // 好友
        friendListPage: (_) => const FriendListPage(),
        friendRequests: (_) => const FriendRequestPage(),
        friendSearch: (_) => const FriendSearchPage(),
        // 群组
        groupCreate: (_) => const GroupCreatePage(),
        // 签到
        signIn: (_) => const SignPage(),
        // 爱心中心
        wallet: (_) => const WalletPage(),
        walletRecharge: (_) => const RechargePage(),
        walletWithdraw: (_) => const WithdrawPage(),
        walletTransactions: (_) => const TransactionHistoryPage(),
        // 抽奖
        lottery: (_) => const LotteryPage(),
        // VIP
        vipCenter: (_) => const VipCenterPage(),
      };

  /// Web 深链接待消费目标：主页加载后由 SplashPage 消费并跳转
  /// 用于 https://host/#/post/detail?id=123 这类链接直达详情
  static int? pendingPostDetailId;

  /// 应用启动时调用，解析浏览器初始 URL，生成初始路由栈
  /// - 始终以 splash 为栈底，避免 push/replacement 与 deep link 冲突
  /// - 若 URL 含 /post/detail?id=xxx，将 id 暂存到 pendingPostDetailId
  static List<Route<dynamic>> onGenerateInitialRoutes(String initialRoute) {
    try {
      final uri = Uri.parse(initialRoute);
      if (uri.path == postDetail) {
        final id = int.tryParse(uri.queryParameters['id'] ?? '');
        if (id != null) pendingPostDetailId = id;
      }
    } catch (_) {}
    return [
      MaterialPageRoute(
        settings: const RouteSettings(name: splash),
        builder: (_) => const SplashPage(),
      ),
    ];
  }

  /// 需要传参的页面，用 onGenerateRoute
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    // 兼容 Web 深链接：settings.name 可能是 "/post/detail?id=123"
    final rawName = settings.name ?? '';
    final uri = Uri.tryParse(rawName);
    final path = uri?.path ?? rawName;

    if (path == postDetail) {
      int? postId;
      if (settings.arguments is int) {
        postId = settings.arguments as int;
      } else {
        postId = int.tryParse(uri?.queryParameters['id'] ?? '');
      }
      if (postId == null) return null;
      return MaterialPageRoute(
        settings: RouteSettings(name: postDetail, arguments: postId),
        builder: (_) => PostDetailPage(postId: postId!),
      );
    }
    if (settings.name == postEdit) {
      final post = settings.arguments as PostModel;
      return MaterialPageRoute(
        builder: (_) => PostEditPage(post: post),
      );
    }
    if (settings.name == privateChat) {
      final args = settings.arguments as Map<String, dynamic>;
      return MaterialPageRoute(
        builder: (_) => PrivateChatPage(
          friendId: args['friendId'] as int,
          friendName: args['friendName'] as String,
          friendAvatar: args['friendAvatar'] as String? ?? '',
          friendUserCode: args['friendUserCode'] as String? ?? '',
          friendIsOfficial: args['friendIsOfficial'] as bool? ?? false,
        ),
      );
    }
    if (settings.name == groupChat) {
      final groupId = settings.arguments as int;
      return MaterialPageRoute(
        builder: (_) => GroupChatPage(groupId: groupId),
      );
    }
    if (settings.name == groupDetail) {
      final groupId = settings.arguments as int;
      return MaterialPageRoute(
        builder: (_) => GroupDetailPage(groupId: groupId),
      );
    }
    if (settings.name == redPacketDetail) {
      final redPacketId = settings.arguments as int;
      return MaterialPageRoute(
        builder: (_) => RedPacketDetailPage(redPacketId: redPacketId),
      );
    }
    return null;
  }
}
