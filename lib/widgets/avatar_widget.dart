import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../utils/url_helper.dart';

/// 通用头像组件 — 支持系统头像、网络图片、字母占位
/// 系统头像兼容完整 URL 和相对路径格式
class AvatarWidget extends StatelessWidget {
  final String avatarPath;
  final String name;
  final double size;
  final double? borderRadius;

  const AvatarWidget({
    super.key,
    required this.avatarPath,
    required this.name,
    this.size = 40,
    this.borderRadius,
  });

  /// System avatar color and icon mapping
  static const _systemAvatarStyles = <String, List<dynamic>>{
    '/system/avatars/avatar_1.svg': [Color(0xFF4A90D9), Icons.person],
    '/system/avatars/avatar_2.svg': [Color(0xFF5BA0E8), Icons.person_outline],
    '/system/avatars/avatar_3.svg': [Color(0xFF34A853), Icons.face],
    '/system/avatars/avatar_4.svg': [Color(0xFF8B5CF6), Icons.sentiment_satisfied_alt],
    '/system/avatars/avatar_5.svg': [Color(0xFFF97316), Icons.emoji_people],
    '/system/avatars/avatar_6.svg': [Color(0xFFEC4899), Icons.face_3],
    '/system/avatars/avatar_7.svg': [Color(0xFFF43F5E), Icons.face_4],
    '/system/avatars/avatar_8.svg': [Color(0xFFA855F7), Icons.face_2],
    '/system/avatars/avatar_9.svg': [Color(0xFF06B6D4), Icons.face_5],
    '/system/avatars/avatar_10.svg': [Color(0xFFEAB308), Icons.face_6],
  };

  /// 从路径中提取系统头像 key（兼容完整 URL 和相对路径）
  static String? extractSystemAvatarKey(String path) {
    if (path.contains('/system/avatars/')) {
      final match = RegExp(r'/system/avatars/avatar_\d+\.svg').firstMatch(path);
      return match?.group(0);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';
    final radius = borderRadius ?? size / 2;

    // 提取系统头像 key
    final systemKey = extractSystemAvatarKey(avatarPath);

    // System preset avatar
    if (systemKey != null) {
      final style = _systemAvatarStyles[systemKey];
      final color = (style != null ? style[0] : AppTheme.primaryColor) as Color;
      final icon = (style != null ? style[1] : Icons.person) as IconData;

      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Center(
          child: Icon(icon, size: size * 0.55, color: color),
        ),
      );
    }

    // Network image avatar
    if (avatarPath.isNotEmpty) {
      final absUrl = UrlHelper.ensureAbsolute(avatarPath);
      if (UrlHelper.isValidNetworkUrl(absUrl)) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: CachedNetworkImage(
            imageUrl: absUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholder: (_, __) => _letterAvatar(initial, radius),
            errorWidget: (_, __, ___) => _letterAvatar(initial, radius),
          ),
        );
      }
    }

    // Default letter placeholder
    return _letterAvatar(initial, radius);
  }

  Widget _letterAvatar(String initial, double radius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: size * 0.39,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }
}
