/// 响应式布局工具
///
/// 提供自适应布局、屏幕尺寸检测、双栏布局等功能，
/// 支持手机和平板的响应式设计�?
library;

import 'package:flutter/material.dart';

/// 屏幕尺寸类型
enum ScreenSize {
  /// 手机（小屏）
  phone,

  /// 平板（中屏）
  tablet,

  /// 桌面/大屏平板
  desktop,
}

/// 布局方向
enum LayoutDirection {
  /// 垂直布局（单栏）
  vertical,

  /// 水平布局（双栏）
  horizontal,
}

/// 响应式布局配置
class ResponsiveConfig {
  /// 平板最小宽度（逻辑像素�?
  final double tabletBreakpoint;

  /// 桌面最小宽度（逻辑像素�?
  final double desktopBreakpoint;

  const ResponsiveConfig({
    this.tabletBreakpoint = 600,
    this.desktopBreakpoint = 1024,
  });

  /// 默认配置
  static const defaultConfig = ResponsiveConfig();
}

/// 响应式布局构建�?
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

/// 自适应双栏布局
///
/// 在大屏幕上显示双栏（主内�?+ 侧边栏）�?/// 在小屏幕上显示单栏（通过导航切换）�?
class AdaptiveTwoPaneLayout extends StatelessWidget {
  /// 主内容区�?
  final Widget mainContent;

  /// 侧边栏内�?
  final Widget sideContent;

  /// 侧边栏宽度（平板/桌面�?
  final double sidePaneWidth;

  /// 是否强制显示双栏
  final bool forceTwoPane;

  /// 侧边栏位�?
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
            // 水平双栏（左右布局�?
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
            // 垂直双栏（上下布局�?
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
          // 单栏模式，只显示主内�?
          return mainContent;
        }
      },
    );
  }
}

/// 自适应导航�?///
/// 在大屏幕上显示永久侧边栏�?/// 在小屏幕上显示抽屉式导航�?
class AdaptiveNavigation extends StatelessWidget {
  final Widget body;
  final Widget drawerContent;
  final Widget? fab;
  final bool showFab;

  const AdaptiveNavigation({
    super.key,
    required this.body,
    required this.drawerContent,
    this.fab,
    this.showFab = true,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, screenSize, constraints) {
        final isLargeScreen =
            screenSize == ScreenSize.tablet || screenSize == ScreenSize.desktop;

        if (isLargeScreen) {
          // 大屏幕：使用永久侧边�?
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
          // 小屏幕：使用抽屉式导�?
          return Scaffold(
            appBar: AppBar(title: const Text('Zephyr Reader')),
            drawer: Drawer(child: drawerContent),
            body: body,
            floatingActionButton: showFab ? fab : null,
          );
        }
      },
    );
  }
}

/// 响应式网�?///
/// 根据屏幕宽度自动调整列数�?
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minColumnWidth;
  final double spacing;
  final double runSpacing;
  final EdgeInsetsGeometry padding;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minColumnWidth = 200,
    this.spacing = 12,
    this.runSpacing = 12,
    this.padding = const EdgeInsets.all(12),
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
            childAspectRatio: 0.65,
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            children: children,
          ),
        );
      },
    );
  }
}

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

/// 检查是否为平板或更大屏�?
bool isTablet(BuildContext context) {
  return getScreenSize(context) != ScreenSize.phone;
}

/// 检查是否为桌面屏幕
bool isDesktop(BuildContext context) {
  return getScreenSize(context) == ScreenSize.desktop;
}
