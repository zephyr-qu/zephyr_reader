import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/core/presentation/widgets/adaptive_layout.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/core/utils/haptic.dart';

/// 底部导航栏配置
enum BottomNavItem {
  home(
    icon: PhosphorIconsRegular.house,
    activeIcon: PhosphorIconsFill.house,
    route: RoutePaths.home,
    routeName: RouteNames.home,
  ),
  bookshelf(
    icon: PhosphorIconsRegular.bookOpenText,
    activeIcon: PhosphorIconsFill.bookOpenText,
    route: RoutePaths.bookshelf,
    routeName: RouteNames.bookshelf,
  ),
  statistics(
    icon: PhosphorIconsRegular.chartBar,
    activeIcon: PhosphorIconsFill.chartBar,
    route: RoutePaths.statistics,
    routeName: RouteNames.statistics,
  ),
  profile(
    icon: PhosphorIconsRegular.user,
    activeIcon: PhosphorIconsFill.user,
    route: RoutePaths.profile,
    routeName: RouteNames.profile,
  );

  final IconData icon;
  final IconData activeIcon;
  final String route;
  final String routeName;

  const BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.route,
    required this.routeName,
  });

  /// 获取当前导航项对应的本地化标签文本
  String label(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return switch (this) {
      BottomNavItem.home => l10n.tabHome,
      BottomNavItem.bookshelf => l10n.tabBookshelf,
      BottomNavItem.statistics => l10n.tabStatistics,
      BottomNavItem.profile => l10n.tabProfile,
    };
  }

  /// 判断当前路由是否匹配此导航项
  bool matchesRoute(String currentRoute) {
    final normalizedRoute = currentRoute.split('?').first;

    if (this == BottomNavItem.bookshelf) {
      return normalizedRoute == route || normalizedRoute.startsWith('/books/');
    }
    if (this == BottomNavItem.statistics) {
      return normalizedRoute == route ||
          normalizedRoute.startsWith('/statistics/');
    }
    if (this == BottomNavItem.profile) {
      return normalizedRoute == route ||
          normalizedRoute.startsWith('/profile/');
    }
    return normalizedRoute == route;
  }
}

/// 带自适应导航栏的主布局
class MainLayout extends HookWidget {
  /// 子页面内容
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).uri.path;
    final deviceType = LayoutBreakpoints.getScreenSizeClass(context);
    final isTabletOrDesktop =
        deviceType == ScreenSizeClass.medium ||
        deviceType == ScreenSizeClass.expanded;
    final theme = Theme.of(context);

    final currentIndex = _calculateSelectedIndex(currentRoute);

    if (isTabletOrDesktop) {
      return Scaffold(
        body: Row(
          children: [
            _buildSideBar(context, deviceType, currentIndex, theme),
            VerticalDivider(
              thickness: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            Expanded(child: child),
          ],
        ),
      );
    } else {
      return Scaffold(
        body: child,
        extendBody: false,
        bottomNavigationBar: _buildBottomNavigationBar(
          context,
          currentIndex,
          theme,
        ),
      );
    }
  }

  /// 构建侧边栏（平板/桌面端自适应导航）
  Widget _buildSideBar(
    BuildContext context,
    ScreenSizeClass deviceType,
    int currentIndex,
    ThemeData theme,
  ) {
    final isExtended = deviceType == ScreenSizeClass.expanded;

    return Container(
      width: isExtended ? 200 : 72,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: theme.dividerColor, width: 0.5),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildLogo(context, deviceType, theme),
            const SizedBox(height: 32),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: BottomNavItem.values.asMap().entries.map((entry) {
                  final index = entry.key;
                  final navItem = entry.value;
                  return _buildRailDestination(
                    context,
                    navItem,
                    index,
                    currentIndex,
                    theme,
                    isExtended,
                  );
                }).toList(),
              ),
            ),
            _buildBottomActions(context, theme, isExtended),
          ],
        ),
      ),
    );
  }

  /// 构建侧边栏顶部的应用 Logo
  Widget _buildLogo(
    BuildContext context,
    ScreenSizeClass deviceType,
    ThemeData theme,
  ) {
    final isExtended = deviceType == ScreenSizeClass.expanded;

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: 24,
        horizontal: isExtended ? 16 : 12,
      ),
      child: Row(
        children: [
          Icon(
            PhosphorIconsRegular.bookOpenText,
            color: theme.colorScheme.primary,
            size: 24,
          ),
          if (isExtended) ...[
            const SizedBox(width: 10),
            Text(
              'Zephyr',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建侧边栏中的单个导航目的地项
  Widget _buildRailDestination(
    BuildContext context,
    BottomNavItem navItem,
    int index,
    int currentIndex,
    ThemeData theme,
    bool isExtended,
  ) {
    final isSelected = index == currentIndex;

    final activeColor = theme.colorScheme.primary;
    final inactiveColor = theme.colorScheme.onSurfaceVariant;

    return Semantics(
      label: navItem.label(context),
      button: true,
      child: GestureDetector(
        onTap: () => context.go(navItem.route),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              Icon(
                isSelected ? navItem.activeIcon : navItem.icon,
                color: isSelected ? activeColor : inactiveColor,
                size: 22,
              ),
              if (isExtended) ...[
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        navItem.label(context),
                        style: TextStyle(
                          fontSize: 14,
                          color: isSelected ? activeColor : inactiveColor,
                          fontWeight: isSelected
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                      ),
                      if (isSelected)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          height: 2,
                          width: 18,
                          decoration: BoxDecoration(
                            color: activeColor,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 构建侧边栏底部操作区域
  Widget _buildBottomActions(
    BuildContext context,
    ThemeData theme,
    bool isExtended,
  ) {
    return const SizedBox.shrink();
  }

  /// 构建底部导航栏（移动端）
  Widget _buildBottomNavigationBar(
    BuildContext context,
    int currentIndex,
    ThemeData theme,
  ) {
    final activeColor = theme.colorScheme.primary;
    final inactiveColor = theme.colorScheme.onSurfaceVariant;

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.dividerColor, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: BottomNavItem.values.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = index == currentIndex;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    context.go(item.route);
                    hapticFeedback(HapticType.light);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedScale(
                    scale: isSelected ? 1.0 : 0.9,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected ? item.activeIcon : item.icon,
                          size: 22,
                          color: isSelected ? activeColor : inactiveColor,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label(context),
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected ? activeColor : inactiveColor,
                            fontWeight: isSelected
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 2,
                          width: isSelected ? 20 : 0,
                          decoration: BoxDecoration(
                            color: activeColor,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  /// 计算当前路由对应的导航索引
  int _calculateSelectedIndex(String currentRoute) {
    for (var i = 0; i < BottomNavItem.values.length; i++) {
      if (BottomNavItem.values[i].matchesRoute(currentRoute)) {
        return i;
      }
    }
    return 0;
  }
}
