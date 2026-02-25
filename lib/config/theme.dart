import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // ========== 品牌色系 ==========
  static const Color primaryColor = Color(0xFF4A90D9);
  static const Color primaryLight = Color(0xFFE8F0FE);
  static const Color primaryDark = Color(0xFF2C5F8A);
  static const Color accentColor = Color(0xFFF5A623);
  static const Color dangerColor = Color(0xFFE74C3C);
  static const Color successColor = Color(0xFF27AE60);
  static const Color warningColor = Color(0xFFF39C12);

  // ========== 背景色 ==========
  static const Color scaffoldBg = Color(0xFFF5F6FA);
  static const Color cardBg = Colors.white;
  static const Color dividerColor = Color(0xFFEEEEEE);

  // ========== 文本色 ==========
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFFBEC3CC);

  // ========== 分类颜色（柔和配色 + 背景色） ==========
  static const Color petColor = Color(0xFFF59E0B);
  static const Color petBg = Color(0xFFFEF3C7);
  static const Color elderColor = Color(0xFF3B82F6);
  static const Color elderBg = Color(0xFFDBEAFE);
  static const Color childColor = Color(0xFFEF4444);
  static const Color childBg = Color(0xFFFEE2E2);
  static const Color otherColor = Color(0xFF8B5CF6);
  static const Color otherBg = Color(0xFFEDE9FE);

  /// "其它" 分组包含的分类（宠物 + 其它物品）
  static const List<int> otherGroup = [1, 4];

  static Color getCategoryColor(int category) {
    switch (category) {
      case 1: return petColor;
      case 2: return elderColor;
      case 3: return childColor;
      case 4: return otherColor;
      default: return primaryColor;
    }
  }

  static Color getCategoryBgColor(int category) {
    switch (category) {
      case 1: return petBg;
      case 2: return elderBg;
      case 3: return childBg;
      case 4: return otherBg;
      default: return primaryLight;
    }
  }

  static IconData getCategoryIcon(int category) {
    switch (category) {
      case 1: return Icons.pets;
      case 2: return Icons.elderly;
      case 3: return Icons.child_care;
      case 4: return Icons.inventory_2_outlined;
      default: return Icons.help_outline;
    }
  }

  static String getCategoryName(int category) {
    switch (category) {
      case 1: return '宠物';
      case 2: return '成年人';
      case 3: return '儿童';
      case 4: return '其它物品';
      default: return '未知';
    }
  }

  // ========== 阴影 ==========
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 12,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];

  // ========== 主题 ==========
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        surface: cardBg,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0.5,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 2.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: primaryColor, width: 1.5),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dangerColor),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: textHint, fontSize: 14),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
      ),
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 0.5,
        space: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
