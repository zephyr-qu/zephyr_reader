import 'package:flutter/material.dart';

/// 布局断点定义
/// 参数参考自 Material Design 响应式布局规范
class LayoutBreakpoints {
  /// 手机-600dp
  static const double phoneMax = 600;

  /// 平板00-840dp
  static const double tabletMin = 600;
  static const double tabletMax = 840;

  /// 桌面 840dp
  static const double desktopMin = 840;

  /// 判断是否为手
  static bool isPhone(BuildContext context) {
    return MediaQuery.of(context).size.width < phoneMax;
  }

  /// 判断是否为平
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= tabletMin && width < desktopMin;
  }

  /// 判断是否为桌大屏
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopMin;
  }

  /// 获取当前设备类型
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < phoneMax) {
      return DeviceType.phone;
    } else if (width < desktopMin) {
      return DeviceType.tablet;
    } else {
      return DeviceType.desktop;
    }
  }

  /// 获取合适的网格列数
  static int getGridCrossAxisCount(BuildContext context) {
    final type = getDeviceType(context);
    return switch (type) {
      DeviceType.phone => 2,
      DeviceType.tablet => 4,
      DeviceType.desktop => 6,
    };
  }

  /// 获取合适的边距
  static EdgeInsets getPagePadding(BuildContext context) {
    final type = getDeviceType(context);
    return switch (type) {
      DeviceType.phone => const EdgeInsets.all(16),
      DeviceType.tablet => const EdgeInsets.all(24),
      DeviceType.desktop => const EdgeInsets.all(32),
    };
  }

  /// 获取合适的卡片边距
  static double getCardPadding(BuildContext context) {
    final type = getDeviceType(context);
    return switch (type) {
      DeviceType.phone => 16,
      DeviceType.tablet => 20,
      DeviceType.desktop => 24,
    };
  }

  /// 获取合适的间距
  static double getSpacing(BuildContext context) {
    final type = getDeviceType(context);
    return switch (type) {
      DeviceType.phone => 12,
      DeviceType.tablet => 16,
      DeviceType.desktop => 24,
    };
  }
}

/// 设备类型枚举
enum DeviceType { phone, tablet, desktop }

/// 自适应布局助手
class AdaptiveLayout {
  /// 根据设备类型返回不同
  /// Widget
  static Widget buildForDevice({
    required BuildContext context,
    required Widget Function(BuildContext context, DeviceType type) builder,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return builder(context, LayoutBreakpoints.getDeviceType(context));
      },
    );
  }

  /// 响应式网格布局
  static Widget responsiveGrid({
    required BuildContext context,
    required List<Widget> children,
    int? crossAxisCount,
    double? childAspectRatio,
  }) {
    final count =
        crossAxisCount ?? LayoutBreakpoints.getGridCrossAxisCount(context);
    final spacing = LayoutBreakpoints.getSpacing(context);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: count,
        childAspectRatio: childAspectRatio ?? 0.7,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }

  /// 响应式列表布局
  static Widget responsiveList({
    required BuildContext context,
    required List<Widget> children,
    Axis scrollDirection = Axis.vertical,
  }) {
    final spacing = LayoutBreakpoints.getSpacing(context);

    if (scrollDirection == Axis.horizontal) {
      return ListView.separated(
        shrinkWrap: true,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: children.length,
        separatorBuilder: (context, _) => SizedBox(width: spacing),
        itemBuilder: (context, index) => children[index],
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: children.length,
      separatorBuilder: (context, _) => SizedBox(height: spacing),
      itemBuilder: (context, index) => children[index],
    );
  }
}
