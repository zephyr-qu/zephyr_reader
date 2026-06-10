import 'package:flutter/material.dart';

// ============================================================================
// 断点定义
// ============================================================================

/// 布局断点工具类，提供基于宽度的屏幕尺寸分类和自适应布局辅助方法。
///
/// 断点定义：compact < 600px < medium < 840px < expanded。
///
/// 所有判断均基于窗口/可用宽度，不依赖任何硬件类型信息。
class LayoutBreakpoints {
  static const double compactMax = 600;
  static const double mediumMin = 600;
  static const double mediumMax = 840;
  static const double expandedMin = 840;

  static bool isCompact(BuildContext context) {
    return MediaQuery.sizeOf(context).width < compactMax;
  }

  static bool isMedium(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= mediumMin && width < expandedMin;
  }

  static bool isExpanded(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= expandedMin;
  }

  /// 根据 [MediaQuery.sizeOf] 的窗口宽度返回屏幕尺寸分类。
  static ScreenSizeClass getScreenSizeClass(BuildContext context) {
    return classifyWidth(MediaQuery.sizeOf(context).width);
  }
  
  /// 根据给定的原始宽度值返回屏幕尺寸分类。
  ///
  /// 可与 [LayoutBuilder] 配合使用，使布局响应实际父级分配的空间，
  /// 而非窗口总宽度（例如侧边栏存在时）。
  static ScreenSizeClass classifyWidth(double width) {
    if (width < compactMax) return ScreenSizeClass.compact;
    if (width < expandedMin) return ScreenSizeClass.medium;
    return ScreenSizeClass.expanded;
  }

  /// 根据给定宽度返回网格跨列数。
  ///
  /// 可与 [LayoutBuilder] 配合使用，用 [constraints.maxWidth] 替代窗口宽度，
  /// 使网格响应实际可用空间（例如侧边栏打开时）。
  static int getGridCrossAxisCount(double width) {
    final type = classifyWidth(width);
    return switch (type) {
      ScreenSizeClass.compact => 3,
      ScreenSizeClass.medium => 4,
      ScreenSizeClass.expanded => 6,
    };
  }

  static EdgeInsets getPagePadding(BuildContext context) {
    final type = getScreenSizeClass(context);
    return switch (type) {
      ScreenSizeClass.compact => const EdgeInsets.all(16),
      ScreenSizeClass.medium => const EdgeInsets.all(24),
      ScreenSizeClass.expanded => const EdgeInsets.all(32),
    };
  }

  static double getCardPadding(BuildContext context) {
    final type = getScreenSizeClass(context);
    return switch (type) {
      ScreenSizeClass.compact => 16,
      ScreenSizeClass.medium => 20,
      ScreenSizeClass.expanded => 24,
    };
  }

  static double getSpacing(BuildContext context) {
    final type = getScreenSizeClass(context);
    return switch (type) {
      ScreenSizeClass.compact => 12,
      ScreenSizeClass.medium => 16,
      ScreenSizeClass.expanded => 24,
    };
  }
}

// ============================================================================
// 屏幕尺寸分类
// ============================================================================

/// 基于窗口宽度的屏幕尺寸分类，不反映任何硬件设备类型。
enum ScreenSizeClass { compact, medium, expanded }
