import 'package:flutter/material.dart';

// ============================================================================
// 断点定义
// ============================================================================

/// 布局断点工具类，提供设备类型判断和自适应布局辅助方法。
///
/// 断点定义：phone < 600px < tablet < 840px < desktop。
class LayoutBreakpoints {
  static const double phoneMax = 600;
  static const double tabletMin = 600;
  static const double tabletMax = 840;
  static const double desktopMin = 840;

  static bool isPhone(BuildContext context) {
    return MediaQuery.sizeOf(context).width < phoneMax;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= tabletMin && width < desktopMin;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= desktopMin;
  }

  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < phoneMax) {
      return DeviceType.phone;
    } else if (width < desktopMin) {
      return DeviceType.tablet;
    } else {
      return DeviceType.desktop;
    }
  }

  static int getGridCrossAxisCount(BuildContext context) {
    final type = getDeviceType(context);
    return switch (type) {
      DeviceType.phone => 2,
      DeviceType.tablet => 4,
      DeviceType.desktop => 6,
    };
  }

  static EdgeInsets getPagePadding(BuildContext context) {
    final type = getDeviceType(context);
    return switch (type) {
      DeviceType.phone => const EdgeInsets.all(16),
      DeviceType.tablet => const EdgeInsets.all(24),
      DeviceType.desktop => const EdgeInsets.all(32),
    };
  }

  static double getCardPadding(BuildContext context) {
    final type = getDeviceType(context);
    return switch (type) {
      DeviceType.phone => 16,
      DeviceType.tablet => 20,
      DeviceType.desktop => 24,
    };
  }

  static double getSpacing(BuildContext context) {
    final type = getDeviceType(context);
    return switch (type) {
      DeviceType.phone => 12,
      DeviceType.tablet => 16,
      DeviceType.desktop => 24,
    };
  }
}

// ============================================================================
// 设备类型枚举
// ============================================================================

enum DeviceType { phone, tablet, desktop }

// ============================================================================
// 导航模式
// ============================================================================

enum NavigationMode {
  bottomNavigationBar,
  navigationRail,
  permanentNavigationRail,
}
