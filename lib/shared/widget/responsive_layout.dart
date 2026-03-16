/// 响应式布局工具
///
/// 提供平板、桌面等大屏设备的响应式布局支持
library;

import 'package:flutter/material.dart';

/// 响应式布局助手
class ResponsiveLayout {
  /// 获取屏幕宽度类型
  static ScreenWidthType getScreenWidthType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) {
      return ScreenWidthType.compact;
    } else if (width < 840) {
      return ScreenWidthType.medium;
    } else {
      return ScreenWidthType.expanded;
    }
  }

  /// 是否为窄屏（手机竖屏
  static bool isCompact(BuildContext context) {
    return getScreenWidthType(context) == ScreenWidthType.compact;
  }

  /// 是否为中等屏幕（手机横屏/小平板）
  static bool isMedium(BuildContext context) {
    return getScreenWidthType(context) == ScreenWidthType.medium;
  }

  /// 是否为宽屏（平板/桌面
  static bool isExpanded(BuildContext context) {
    return getScreenWidthType(context) == ScreenWidthType.expanded;
  }

  /// 获取合适的列数
  static int getColumnCount(BuildContext context) {
    return switch (getScreenWidthType(context)) {
      ScreenWidthType.compact => 1,
      ScreenWidthType.medium => 2,
      ScreenWidthType.expanded => 3,
    };
  }

  /// 获取合适的导航模式
  static NavigationMode getNavigationMode(BuildContext context) {
    if (isCompact(context)) {
      return NavigationMode.bottomNavigationBar;
    } else {
      return NavigationMode.navigationRail;
    }
  }

  /// 构建响应式布局
  static Widget build({
    required BuildContext context,
    required Widget compact,
    Widget? medium,
    Widget? expanded,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final widthType = getScreenWidthTypeFromConstraints(constraints);
        return switch (widthType) {
          ScreenWidthType.compact => compact,
          ScreenWidthType.medium => medium ?? compact,
          ScreenWidthType.expanded => expanded ?? medium ?? compact,
        };
      },
    );
  }

  static ScreenWidthType getScreenWidthTypeFromConstraints(
    BoxConstraints constraints,
  ) {
    final width = constraints.maxWidth;
    if (width < 600) {
      return ScreenWidthType.compact;
    } else if (width < 840) {
      return ScreenWidthType.medium;
    } else {
      return ScreenWidthType.expanded;
    }
  }
}

/// 屏幕宽度类型
enum ScreenWidthType {
  /// 窄屏 600dp
  compact,

  /// 中等屏幕00-840dp
  medium,

  /// 宽屏 840dp
  expanded,
}

/// 导航模式
enum NavigationMode {
  /// 底部导航
  bottomNavigationBar,

  /// 侧边导航
  navigationRail,

  /// 永久侧边
  permanentNavigationRail,
}

/// 响应式页面脚手架
class ResponsiveScaffold extends StatelessWidget {
  final Widget body;
  final Widget? bottomBar;
  final Widget? navigationRail;
  final PreferredSizeWidget? appBar;

  const ResponsiveScaffold({
    super.key,
    required this.body,
    this.bottomBar,
    this.navigationRail,
    this.appBar,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = ResponsiveLayout.isCompact(context);

    if (isCompact) {
      return Scaffold(
        appBar: appBar,
        body: body,
        bottomNavigationBar: bottomBar,
      );
    } else {
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            ?navigationRail,
            VerticalDivider(thickness: 1, width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }
  }
}
