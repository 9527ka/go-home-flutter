/// API 配置
class ApiConfig {
  // 开发环境
  static const String devBaseUrl = 'http://127.0.0.1:8080';

  // 生产环境
  static const String prodBaseUrl = 'https://api-gohome.douwen.me';

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
  static const String bindApple = '/api/auth/bind-apple';
  static const String changePassword = '/api/auth/change-password';

  // App 配置
  static const String configApp = '/api/config/app';

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
  static const String notificationDeleteAll = '/api/notification/deleteAll';

  // 账号注销
  static const String deleteAccount = '/api/auth/delete-account';

  // 设备推送令牌
  static const String deviceRegisterToken = '/api/device/register-token';
  static const String deviceUnregisterToken = '/api/device/unregister-token';

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
  static const String friendRemark = '/api/friend/remark';

  // 群组
  static const String groupCreate = '/api/group/create';
  static const String groupList = '/api/group/list';
  static const String groupDetail = '/api/group/detail';
  static const String groupUpdate = '/api/group/update';
  static const String groupInvite = '/api/group/invite';
  static const String groupLeave = '/api/group/leave';
  static const String groupKick = '/api/group/kick';
  static const String groupDisband = '/api/group/disband';
  static const String groupSetRole = '/api/group/set-role';
  static const String groupSetAlias = '/api/group/set-alias';
  static const String groupMuteMember = '/api/group/mute-member';
  static const String groupSetAllMuted = '/api/group/set-all-muted';
  static const String groupInviteToken = '/api/group/invite-token';
  static const String groupJoinByToken = '/api/group/join-by-token';
  static const String groupMessages = '/api/group/messages';

  // 私聊
  static const String pmHistory = '/api/pm/history';
  static const String pmConversations = '/api/pm/conversations';
  static const String pmRead = '/api/pm/read';
  static const String pmMute = '/api/pm/mute';

  // 腾讯云 TRTC（私聊语音通话）
  static const String rtcUserSig = '/api/rtc/user-sig';

  // 用户信息
  static const String userInfo = '/api/user/info';

  // 爱心中心
  static const String walletInfo = '/api/wallet/info';
  static const String walletTransactions = '/api/wallet/transactions';
  static const String walletRecharge = '/api/wallet/recharge';
  static const String walletIapRecharge = '/api/wallet/iap-recharge';
  static const String walletRechargeList = '/api/wallet/recharge/list';
  static const String walletWithdraw = '/api/wallet/withdraw';
  static const String walletWithdrawList = '/api/wallet/withdraw/list';
  static const String walletDonate = '/api/wallet/donate';
  static const String walletBoost = '/api/wallet/boost';
  static const String walletBoostActive = '/api/wallet/boost/active';
  static const String walletRewardPay = '/api/wallet/reward/pay';

  // 签到
  static const String signStatus = '/api/sign/status';
  static const String signIn = '/api/sign';

  // 任务
  static const String taskList = '/api/tasks';
  static const String taskComplete = '/api/task/complete';

  // 红包
  static const String redPacketSend = '/api/red-packet/send';
  static const String redPacketClaim = '/api/red-packet/claim';
  static const String redPacketDetail = '/api/red-packet/detail';

  // 点赞
  static const String likeToggle = '/api/like/toggle';
  static const String likeStatus = '/api/like/status';
  static const String likeUsers = '/api/like/users';

  // 评论
  static const String commentCreate = '/api/comment/create';
  static const String commentList = '/api/comment/list';
  static const String commentReplies = '/api/comment/replies';
  static const String commentDelete = '/api/comment/delete';

  // WebSocket
  static const String wsDevUrl = 'ws://127.0.0.1:8383';
  static const String wsProdUrl = 'wss://api-gohome.douwen.me/ws';
  static const String wsUrl = wsProdUrl;
}
