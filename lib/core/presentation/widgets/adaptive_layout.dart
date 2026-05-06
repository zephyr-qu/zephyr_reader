/// 响应式布局工具
///
/// 提供自适应布局、屏幕尺寸检测、双栏布局等功能，
/// 支持手机、平板和桌面的响应式设计
///
/// 参数参考自 Material Design 响应式布局规范
library;

import 'package:flutter/material.dart';

// ============================================================================
// 断点定义
// ============================================================================

/// 布局断点定义
///
/// 参数参考自 Material Design 响应式布局规范
class LayoutBreakpoints {
  /// 手机：< 600dp
  static const double phoneMax = 600;

  /// 平板：600-840dp
  static const double tabletMin = 600;
  static const double tabletMax = 840;

  /// 桌面：> 840dp
  static const double desktopMin = 840;

  /// 判断是否为手机
  static bool isPhone(BuildContext context) {
    return MediaQuery.of(context).size.width < phoneMax;
  }

  /// 判断是否为平板
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= tabletMin && width < desktopMin;
  }

  /// 判断是否为桌面/大屏
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

// ============================================================================
// 设备类型与屏幕尺寸
// ============================================================================

/// 设备类型枚举
enum DeviceType { phone, tablet, desktop }

/// 屏幕尺寸类型
///
/// 与 [DeviceType] 相比，这个枚举更侧重于屏幕尺寸分类
enum ScreenSize {
  /// 手机（小屏）
  phone,

  /// 平板（中屏）
  tablet,

  /// 桌面/大屏平板
  desktop,
}

/// 屏幕宽度类型
///
/// 参考 Material Design 的窗口大小类别
enum ScreenWidthType {
  /// 窄屏 < 600dp (手机竖屏)
  compact,

  /// 中等屏幕 600-840dp (手机横屏/小平板)
  medium,

  /// 宽屏 >= 840dp (平板/桌面)
  expanded,
}

// ============================================================================
// 响应式配置
// ============================================================================

/// 响应式布局配置
///
/// 允许自定义断点，适配特殊场景
class ResponsiveConfig {
  /// 平板最小宽度（逻辑像素）
  final double tabletBreakpoint;

  /// 桌面最小宽度（逻辑像素）
  final double desktopBreakpoint;

  const ResponsiveConfig({
    this.tabletBreakpoint = 600,
    this.desktopBreakpoint = 1024,
  });

  /// 默认配置
  static const defaultConfig = ResponsiveConfig();

  /// Material Design 标准配置
  static const materialDesign = ResponsiveConfig(
    tabletBreakpoint: 600,
    desktopBreakpoint: 840,
  );
}

// ============================================================================
// 布局构建器
// ============================================================================

/// 响应式布局构建器
///
/// 提供底层的响应式布局构建能力，支持自定义配置
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(
    BuildContext context,
    ScreenSize screenSize,
    BoxConstraints constraints,
  )
  builder;

  final ResponsiveConfig config;

  const ResponsiveBuilder({
    super.key,
    required this.builder,
    this.config = ResponsiveConfig.defaultConfig,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final screenSize = _getScreenSize(width, config);
        return builder(context, screenSize, constraints);
      },
    );
  }

  ScreenSize _getScreenSize(double width, ResponsiveConfig config) {
    if (width >= config.desktopBreakpoint) {
      return ScreenSize.desktop;
    } else if (width >= config.tabletBreakpoint) {
      return ScreenSize.tablet;
    } else {
      return ScreenSize.phone;
    }
  }
}

// ============================================================================
// 自适应布局组件
// ============================================================================

/// 自适应布局助手
///
/// 提供常用的响应式布局构建方法
class AdaptiveLayout {
  /// 根据设备类型返回不同的 Widget
  ///
  /// 示例:
  /// ```dart
  /// AdaptiveLayout.buildForDevice(
  ///   context: context,
  ///   builder: (context, type) {
  ///     return switch (type) {
  ///       DeviceType.phone => PhoneLayout(),
  ///       DeviceType.tablet => TabletLayout(),
  ///       DeviceType.desktop => DesktopLayout(),
  ///     };
  ///   },
  /// )
  /// ```
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
  ///
  /// 自动根据设备类型调整列数和间距
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
  ///
  /// 支持水平和垂直方向，自动调整间距
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

/// 自适应双栏布局
///
/// 在大屏幕上显示双栏（主内容 + 侧边栏）
/// 在小屏幕上显示单栏（主内容）
///
/// 示例:
/// ```dart
/// AdaptiveTwoPaneLayout(
///   mainContent: BookList(),
///   sideContent: BookDetail(),
///   sidePaneWidth: 350,
/// )
/// ```
class AdaptiveTwoPaneLayout extends StatelessWidget {
  /// 主内容区
  final Widget mainContent;

  /// 侧边栏内容
  final Widget sideContent;

  /// 侧边栏宽度（平板/桌面）
  final double sidePaneWidth;

  /// 是否强制显示双栏
  final bool forceTwoPane;

  /// 侧边栏位置
  final Axis sidePaneAxis;

  const AdaptiveTwoPaneLayout({
    super.key,
    required this.mainContent,
    required this.sideContent,
    this.sidePaneWidth = 350,
    this.forceTwoPane = false,
    this.sidePaneAxis = Axis.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, screenSize, constraints) {
        final isTwoPane =
            forceTwoPane ||
            screenSize == ScreenSize.tablet ||
            screenSize == ScreenSize.desktop;

        if (isTwoPane) {
          if (sidePaneAxis == Axis.horizontal) {
            // 水平双栏（左右布局）
            return Row(
              children: [
                Expanded(flex: 3, child: mainContent),
                Container(
                  width: sidePaneWidth,
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1,
                      ),
                    ),
                  ),
                  child: sideContent,
                ),
              ],
            );
          } else {
            // 垂直双栏（上下布局）
            return Column(
              children: [
                Expanded(flex: 3, child: mainContent),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1,
                      ),
                    ),
                  ),
                  child: sideContent,
                ),
              ],
            );
          }
        } else {
          // 单栏模式，只显示主内容
          return mainContent;
        }
      },
    );
  }
}

/// 自适应导航
///
/// 在大屏幕上显示永久侧边栏
/// 在小屏幕上显示抽屉式导航
///
/// 示例:
/// ```dart
/// AdaptiveNavigation(
///   body: BookContent(),
///   drawerContent: NavigationMenu(),
/// )
/// ```
class AdaptiveNavigation extends StatelessWidget {
  final Widget body;
  final Widget drawerContent;
  final Widget? fab;
  final bool showFab;
  final String? appBarTitle;

  const AdaptiveNavigation({
    super.key,
    required this.body,
    required this.drawerContent,
    this.fab,
    this.showFab = true,
    this.appBarTitle,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, screenSize, constraints) {
        final isLargeScreen =
            screenSize == ScreenSize.tablet || screenSize == ScreenSize.desktop;

        if (isLargeScreen) {
          // 大屏幕：使用永久侧边栏
          return Scaffold(
            body: Row(
              children: [
                Container(
                  width: 250,
                  color: Theme.of(context).cardColor,
                  child: drawerContent,
                ),
                Expanded(child: body),
              ],
            ),
            floatingActionButton: showFab ? fab : null,
          );
        } else {
          // 小屏幕：使用抽屉式导航
          return Scaffold(
            appBar: AppBar(title: Text(appBarTitle ?? 'Zephyr Reader')),
            drawer: Drawer(child: drawerContent),
            body: body,
            floatingActionButton: showFab ? fab : null,
          );
        }
      },
    );
  }
}

/// 响应式网格
///
/// 根据屏幕宽度自动调整列数
///
/// 示例:
/// ```dart
/// ResponsiveGrid(
///   minColumnWidth: 200,
///   children: bookCovers,
/// )
/// ```
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minColumnWidth;
  final double spacing;
  final double runSpacing;
  final EdgeInsetsGeometry padding;
  final double childAspectRatio;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minColumnWidth = 200,
    this.spacing = 12,
    this.runSpacing = 12,
    this.padding = const EdgeInsets.all(12),
    this.childAspectRatio = 0.65,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, screenSize, constraints) {
        final maxWidth = constraints.maxWidth - padding.horizontal;
        final columnCount = (maxWidth / minColumnWidth).floor().clamp(1, 6);

        return Padding(
          padding: padding,
          child: GridView.count(
            crossAxisCount: columnCount,
            mainAxisSpacing: spacing,
            crossAxisSpacing: runSpacing,
            childAspectRatio: childAspectRatio,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            children: children,
          ),
        );
      },
    );
  }
}

// ============================================================================
// 工具函数
// ============================================================================

/// 获取当前屏幕尺寸
ScreenSize getScreenSize(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  if (width >= ResponsiveConfig.defaultConfig.desktopBreakpoint) {
    return ScreenSize.desktop;
  } else if (width >= ResponsiveConfig.defaultConfig.tabletBreakpoint) {
    return ScreenSize.tablet;
  } else {
    return ScreenSize.phone;
  }
}

/// 检查是否为平板或更大屏
bool isTablet(BuildContext context) {
  return getScreenSize(context) != ScreenSize.phone;
}

/// 检查是否为桌面屏幕
bool isDesktop(BuildContext context) {
  return getScreenSize(context) == ScreenSize.desktop;
}

/// 获取屏幕宽度类型
ScreenWidthType getScreenWidthType(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  if (width < 600) {
    return ScreenWidthType.compact;
  } else if (width < 840) {
    return ScreenWidthType.medium;
  } else {
    return ScreenWidthType.expanded;
  }
}

/// 是否为窄屏（手机竖屏）
bool isCompact(BuildContext context) {
  return getScreenWidthType(context) == ScreenWidthType.compact;
}

/// 是否为中等屏幕（手机横屏/小平板）
bool isMedium(BuildContext context) {
  return getScreenWidthType(context) == ScreenWidthType.medium;
}

/// 是否为宽屏（平板/桌面）
bool isExpanded(BuildContext context) {
  return getScreenWidthType(context) == ScreenWidthType.expanded;
}

/// 获取合适的列数
int getColumnCount(BuildContext context) {
  return switch (getScreenWidthType(context)) {
    ScreenWidthType.compact => 1,
    ScreenWidthType.medium => 2,
    ScreenWidthType.expanded => 3,
  };
}

/// 获取合适的导航模式
NavigationMode getNavigationMode(BuildContext context) {
  if (isCompact(context)) {
    return NavigationMode.bottomNavigationBar;
  } else {
    return NavigationMode.navigationRail;
  }
}

/// 构建响应式布局
///
/// 根据不同屏幕宽度返回不同的 Widget
Widget buildResponsiveLayout({
  required BuildContext context,
  required Widget compact,
  Widget? medium,
  Widget? expanded,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      if (width < 600) {
        return compact;
      } else if (width < 840) {
        return medium ?? compact;
      } else {
        return expanded ?? medium ?? compact;
      }
    },
  );
}

// ============================================================================
// 导航模式
// ============================================================================

/// 导航模式
enum NavigationMode {
  /// 底部导航栏
  bottomNavigationBar,

  /// 侧边导航轨
  navigationRail,

  /// 永久侧边导航
  permanentNavigationRail,
}

// ============================================================================
// 响应式页面脚手架
// ============================================================================

/// 响应式页面脚手架
///
/// 自动根据屏幕尺寸切换导航模式
///
/// 示例:
/// ```dart
/// ResponsiveScaffold(
///   appBar: AppBar(title: Text('Title')),
///   body: Content(),
///   navigationRailContent: Menu(),
///   bottomBarContent: BottomNav(),
/// )
/// ```
class ResponsiveScaffold extends StatelessWidget {
  final Widget body;
  final Widget? bottomBar;
  final Widget? navigationRail;
  final PreferredSizeWidget? appBar;
  final Widget? drawer;

  const ResponsiveScaffold({
    super.key,
    required this.body,
    this.bottomBar,
    this.navigationRail,
    this.appBar,
    this.drawer,
  });

  @override
  Widget build(BuildContext context) {
    final isCompactLayout = isCompact(context);

    if (isCompactLayout) {
      // 小屏幕：底部导航 + 抽屉
      return Scaffold(
        appBar: appBar,
        body: body,
        bottomNavigationBar: bottomBar,
        drawer: drawer,
      );
    } else {
      // 大屏幕：侧边导航
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            if (navigationRail != null) ...[
              navigationRail!,
              const VerticalDivider(thickness: 1, width: 1),
            ],
            Expanded(child: body),
          ],
        ),
      );
    }
  }
}
