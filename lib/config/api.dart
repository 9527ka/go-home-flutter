/// API 配置
class ApiConfig {
  // 开发环境
  static const String devBaseUrl = 'http://127.0.0.1:8080';

  // 生产环境
  static const String prodBaseUrl = 'https://home.dengshop.com';

  // 当前使用
  static const String baseUrl = prodBaseUrl;

  // 接口超时时间（毫秒）
  static const int connectTimeout = 15000;
  static const int receiveTimeout = 15000;

  // 接口路径
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String appleSignIn = '/api/auth/apple-signin';
  static const String profile = '/api/auth/profile';
  static const String updateProfile = '/api/auth/update';
  static const String quickLogin = '/api/auth/quick-login';
  static const String changeAccount = '/api/auth/change-account';
  static const String changePassword = '/api/auth/change-password';

  static const String postCreate = '/api/post/create';
  static const String postUpdate = '/api/post/update';
  static const String postList = '/api/post/list';
  static const String postDetail = '/api/post/detail';
  static const String postMine = '/api/post/mine';
  static const String postUpdateStatus = '/api/post/updateStatus';

  static const String clueCreate = '/api/clue/create';
  static const String clueList = '/api/clue/list';

  static const String uploadImage = '/api/upload/image';
  static const String uploadImages = '/api/upload/images';
  static const String uploadVideo = '/api/upload/video';
  static const String uploadVoice = '/api/upload/voice';

  static const String reportCreate = '/api/report/create';

  static const String favoriteToggle = '/api/favorite/toggle';
  static const String favoriteList = '/api/favorite/list';

  static const String notificationList = '/api/notification/list';
  static const String notificationUnread = '/api/notification/unread';
  static const String notificationRead = '/api/notification/read';

  // 账号注销
  static const String deleteAccount = '/api/auth/delete-account';

  // 反馈
  static const String feedbackCreate = '/api/feedback/create';

  // 聊天
  static const String chatHistory = '/api/chat/history';

  // 好友
  static const String friendRequest = '/api/friend/request';
  static const String friendRequests = '/api/friend/requests';
  static const String friendAccept = '/api/friend/accept';
  static const String friendReject = '/api/friend/reject';
  static const String friendList = '/api/friend/list';
  static const String friendRemove = '/api/friend/remove';
  static const String friendSearch = '/api/friend/search';
  static const String friendRequestCount = '/api/friend/request-count';

  // 群组
  static const String groupCreate = '/api/group/create';
  static const String groupList = '/api/group/list';
  static const String groupDetail = '/api/group/detail';
  static const String groupUpdate = '/api/group/update';
  static const String groupInvite = '/api/group/invite';
  static const String groupLeave = '/api/group/leave';
  static const String groupKick = '/api/group/kick';
  static const String groupDisband = '/api/group/disband';
  static const String groupMessages = '/api/group/messages';

  // 私聊
  static const String pmHistory = '/api/pm/history';
  static const String pmConversations = '/api/pm/conversations';
  static const String pmRead = '/api/pm/read';

  // 用户信息
  static const String userInfo = '/api/user/info';

  // WebSocket
  static const String wsDevUrl = 'ws://127.0.0.1:8282';
  static const String wsProdUrl = 'wss://home.dengshop.com/ws';
  static const String wsUrl = wsProdUrl;
}
