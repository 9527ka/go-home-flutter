import 'package:flutter/material.dart';

/// 响应式布局辅助类
/// 用于适配不同设备（iPhone、iPad）的屏幕尺寸
class ResponsiveHelper {
  /// 判断是否为平板设备
  static bool isTablet(BuildContext context) {
    final MediaQueryData data = MediaQuery.of(context);
    return data.size.shortestSide >= 600;
  }

  /// 判断是否为大屏平板（如 iPad Pro）
  static bool isLargeTablet(BuildContext context) {
    final MediaQueryData data = MediaQuery.of(context);
    return data.size.shortestSide >= 768;
  }

  /// 获取内容最大宽度（平板上内容居中显示，不占满全屏）
  static double getMaxContentWidth(BuildContext context) {
    if (isTablet(context)) {
      return 800; // iPad 上内容最大宽度
    }
    return double.infinity;
  }

  /// 获取响应式的内边距
  static EdgeInsets getResponsivePadding(
    BuildContext context, {
    double mobile = 16.0,
    double tablet = 24.0,
  }) {
    final padding = isTablet(context) ? tablet : mobile;
    return EdgeInsets.all(padding);
  }

  /// 获取响应式的水平内边距
  static EdgeInsets getResponsiveHorizontalPadding(
    BuildContext context, {
    double mobile = 16.0,
    double tablet = 32.0,
  }) {
    final padding = isTablet(context) ? tablet : mobile;
    return EdgeInsets.symmetric(horizontal: padding);
  }

  /// 获取响应式的字体大小
  static double getResponsiveFontSize(
    BuildContext context, {
    required double mobile,
    double? tablet,
  }) {
    if (isTablet(context) && tablet != null) {
      return tablet;
    }
    return mobile;
  }

  /// 获取网格列数
  static int getGridColumnCount(
    BuildContext context, {
    int mobile = 1,
    int tablet = 2,
    int largeTablet = 3,
  }) {
    if (isLargeTablet(context)) {
      return largeTablet;
    }
    if (isTablet(context)) {
      return tablet;
    }
    return mobile;
  }

  /// 创建响应式容器（平板上内容居中）
  static Widget responsiveContainer({
    required BuildContext context,
    required Widget child,
  }) {
    if (isTablet(context)) {
      return Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: getMaxContentWidth(context),
          ),
          child: child,
        ),
      );
    }
    return child;
  }
}
