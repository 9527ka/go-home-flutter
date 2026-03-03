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
import '../pages/chat/chat_page.dart';
import '../pages/chat/conversation_list_page.dart';
import '../pages/chat/blocked_users_page.dart';
import '../pages/chat/private_chat_page.dart';
import '../pages/friend/friend_list_page.dart';
import '../pages/friend/friend_request_page.dart';
import '../pages/friend/friend_search_page.dart';
import '../pages/group/group_create_page.dart';
import '../pages/group/group_chat_page.dart';
import '../pages/group/group_detail_page.dart';

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
  static const String chatRoom = '/chat';
  static const String conversations = '/conversations';
  static const String blockedUsers = '/blocked-users';
  static const String privateChat = '/private-chat';

  // HIDDEN_FEATURE: 好友相关路由（路由保留防崩溃，入口已隐藏）
  static const String friendListPage = '/friends';
  static const String friendRequests = '/friend-requests';
  static const String friendSearch = '/friend-search';

  // 群组
  static const String groupCreate = '/group/create';
  static const String groupChat = '/group/chat';
  static const String groupDetail = '/group/detail';

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
        chatRoom: (_) => const ChatPage(),
        conversations: (_) => const ConversationListPage(),
        blockedUsers: (_) => const BlockedUsersPage(),
        // 好友
        friendListPage: (_) => const FriendListPage(),
        friendRequests: (_) => const FriendRequestPage(),
        friendSearch: (_) => const FriendSearchPage(),
        // 群组
        groupCreate: (_) => const GroupCreatePage(),
      };

  /// 需要传参的页面，用 onGenerateRoute
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    if (settings.name == postDetail) {
      final postId = settings.arguments as int;
      return MaterialPageRoute(
        builder: (_) => PostDetailPage(postId: postId),
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
    return null;
  }
}
