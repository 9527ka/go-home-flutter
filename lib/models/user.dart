class UserModel {
  final int id;
  final String userCode; // 用户编号（对外展示，如 GH5K8M2NXR）
  final String nickname;
  final String avatar;
  final String account;
  final int accountType;
  final String contactPhone;
  final int status;
  final int authProvider; // 1=密码登录 2=Apple登录

  UserModel({
    required this.id,
    this.userCode = '',
    required this.nickname,
    this.avatar = '',
    required this.account,
    this.accountType = 1,
    this.contactPhone = '',
    this.status = 1,
    this.authProvider = 1,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      userCode: json['user_code'] ?? '',
      nickname: json['nickname'] ?? '',
      avatar: json['avatar'] ?? '',
      account: json['account'] ?? '',
      accountType: json['account_type'] ?? 1,
      contactPhone: json['contact_phone'] ?? '',
      status: json['status'] ?? 1,
      authProvider: json['auth_provider'] ?? 1,
    );
  }

  /// 对外展示的用户编号（优先 userCode，兜底显示 ID）
  String get displayId => userCode.isNotEmpty ? userCode : 'GH$id';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_code': userCode,
      'nickname': nickname,
      'avatar': avatar,
      'account': account,
      'account_type': accountType,
      'contact_phone': contactPhone,
      'status': status,
      'auth_provider': authProvider,
    };
  }
}
