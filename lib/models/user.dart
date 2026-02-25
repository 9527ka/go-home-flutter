class UserModel {
  final int id;
  final String nickname;
  final String avatar;
  final String account;
  final int accountType;
  final String contactPhone;
  final int status;
  final int authProvider; // 1=密码登录 2=Apple登录

  UserModel({
    required this.id,
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
      nickname: json['nickname'] ?? '',
      avatar: json['avatar'] ?? '',
      account: json['account'] ?? '',
      accountType: json['account_type'] ?? 1,
      contactPhone: json['contact_phone'] ?? '',
      status: json['status'] ?? 1,
      authProvider: json['auth_provider'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
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
