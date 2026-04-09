/// 表单校验工具类
class Validators {
  /// 手机号校验（中国）
  static String? phone(String? value) {
    if (value == null || value.isEmpty) return '请输入手机号';
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(value)) return '手机号格式不正确';
    return null;
  }

  /// 邮箱校验
  static String? email(String? value) {
    if (value == null || value.isEmpty) return '请输入邮箱';
    if (!RegExp(r'^[\w\.\-]+@[\w\-]+\.[\w\.\-]+$').hasMatch(value)) {
      return '邮箱格式不正确';
    }
    return null;
  }

  /// 账号校验（手机号或邮箱）
  static String? account(String? value) {
    if (value == null || value.isEmpty) return '请输入手机号或邮箱';
    if (value.contains('@')) {
      return email(value);
    }
    return phone(value);
  }

  /// 密码校验
  static String? password(String? value) {
    if (value == null || value.isEmpty) return '请输入密码';
    if (value.length < 6) return '密码不能少于6个字符';
    if (value.length > 32) return '密码不能超过32个字符';
    return null;
  }

  /// 非空校验
  static String? required(String? value, [String fieldName = '此项']) {
    if (value == null || value.trim().isEmpty) return '请填写$fieldName';
    return null;
  }

  /// 最小长度
  static String? minLength(String? value, int min, [String fieldName = '内容']) {
    if (value == null || value.trim().length < min) {
      return '$fieldName至少$min个字符';
    }
    return null;
  }

  /// 联系电话
  static String? contactPhone(String? value) {
    if (value == null || value.isEmpty) return '请输入联系电话';
    // 允许手机号和座机
    if (!RegExp(r'^[\d\-\+\s]{7,20}$').hasMatch(value)) {
      return '电话格式不正确';
    }
    return null;
  }

}
