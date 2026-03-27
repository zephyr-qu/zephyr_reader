import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/features/bookshelf/page/bookshelf_page.dart';
import 'package:zephyr_reader/features/home/page/home_page.dart';
import 'package:zephyr_reader/features/profile/page/profile_page.dart';
import 'package:zephyr_reader/features/statistics/page/statistics_page.dart';
import 'package:zephyr_reader/shared/widget/adaptive_layout.dart';

/// 底部导航栏配置
enum BottomNavItem {
  home(
    label: '首页',
    icon: Icons.home_outlined,
    activeIcon: Icons.home,
    route: RoutePaths.home,
    routeName: RouteNames.home,
  ),
  bookshelf(
    label: '书籍',
    icon: Icons.book_outlined,
    activeIcon: Icons.book,
    route: RoutePaths.bookshelf,
    routeName: RouteNames.bookshelf,
  ),
  statistics(
    label: '统计',
    icon: Icons.bar_chart_outlined,
    activeIcon: Icons.bar_chart,
    route: RoutePaths.statistics,
    routeName: RouteNames.statistics,
  ),
  profile(
    label: '我的',
    icon: Icons.person_outline,
    activeIcon: Icons.person,
    route: RoutePaths.profile,
    routeName: RouteNames.profile,
  );

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;
  final String routeName;

  const BottomNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
    required this.routeName,
  });

  /// 检查路由是否匹配（支持子路由）
  bool matchesRoute(String currentRoute) {
    // 移除查询参数
    final normalizedRoute = currentRoute.split('?').first;

    if (this == BottomNavItem.bookshelf) {
      // 书籍详情页也高亮书籍标签
      return normalizedRoute == route || normalizedRoute.startsWith('/books/');
    }
    if (this == BottomNavItem.statistics) {
      // 统计相关路由
      return normalizedRoute == route || normalizedRoute.startsWith('/statistics/');
    }
    if (this == BottomNavItem.profile) {
      // 个人中心相关路由
      return normalizedRoute == route || normalizedRoute.startsWith('/profile/');
    }
    return normalizedRoute == route;
  }
}

/// 带自适应导航栏的主布局
/// - 手机：NavigationBar 底部导航
/// - 平板：NavigationRail 左侧导航
/// - 桌面：NavigationRail 扩展模式
class MainLayout extends StatefulWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).uri.path;
    final deviceType = LayoutBreakpoints.getDeviceType(context);
    final isTabletOrDesktop =
        deviceType == DeviceType.tablet || deviceType == DeviceType.desktop;
    final theme = Theme.of(context);

    // 计算当前选中的索引（不存储状态，直接计算）
    final currentIndex = _calculateSelectedIndex(currentRoute);

    if (isTabletOrDesktop) {
      // 平板/桌面：使用 NavigationRail 侧边栏布局
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: deviceType == DeviceType.desktop,
              minWidth: 80,
              selectedIndex: currentIndex,
              groupAlignment: 0.0,
              labelType: deviceType == DeviceType.desktop
                  ? NavigationRailLabelType.all
                  : NavigationRailLabelType.none,
              onDestinationSelected: (index) {
                final navItem = BottomNavItem.values[index];
                context.go(navItem.route);
              },
              leading: _buildRailLeading(context, deviceType),
              destinations: BottomNavItem.values.map((navItem) {
                return NavigationRailDestination(
                  icon: _buildNavIcon(
                    icon: navItem.icon,
                    activeIcon: navItem.activeIcon,
                    isSelected: BottomNavItem.values.indexOf(navItem) == currentIndex,
                    theme: theme,
                  ),
                  label: Text(navItem.label),
                );
              }).toList(),
            ),
            VerticalDivider(
              thickness: 1,
              width: 1,
              color: theme.colorScheme.outlineVariant,
            ),
            Expanded(child: widget.child),
          ],
        ),
      );
    } else {
      // 手机：使用 NavigationBar 底部导航
      return Scaffold(
        body: widget.child,
        extendBody: true,
        bottomNavigationBar: _buildBottomNavigationBar(context, currentIndex, theme),
      );
    }
  }

  /// 计算当前选中的索引
  int _calculateSelectedIndex(String currentRoute) {
    for (var i = 0; i < BottomNavItem.values.length; i++) {
      if (BottomNavItem.values[i].matchesRoute(currentRoute)) {
        return i;
      }
    }
    return 0; // 默认首页
  }

  /// 构建 NavigationRail 的 Leading 区域
  Widget _buildRailLeading(BuildContext context, DeviceType deviceType) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primary.withValues(alpha: 0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.auto_stories,
              color: Colors.white,
              size: 24,
            ),
            if (deviceType == DeviceType.desktop) ...[
              const SizedBox(width: 8),
              Text(
                'Zephyr',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建导航图标
  Widget _buildNavIcon({
    required IconData icon,
    required IconData activeIcon,
    required bool isSelected,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isSelected ? theme.colorScheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        isSelected ? activeIcon : icon,
        color: isSelected ? theme.colorScheme.primary : null,
      ),
    );
  }

  /// 构建底部导航栏
  Widget _buildBottomNavigationBar(
    BuildContext context,
    int currentIndex,
    ThemeData theme,
  ) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: NavigationBar(
        height: 72,
        selectedIndex: currentIndex,
        elevation: 0,
        shadowColor: theme.colorScheme.primary.withValues(alpha: 0.15),
        onDestinationSelected: (index) {
          final navItem = BottomNavItem.values[index];
          context.go(navItem.route);
        },
        destinations: BottomNavItem.values.map((navItem) {
          return NavigationDestination(
            icon: _buildNavIcon(
              icon: navItem.icon,
              activeIcon: navItem.activeIcon,
              isSelected: BottomNavItem.values.indexOf(navItem) == currentIndex,
              theme: theme,
            ),
            selectedIcon: _buildNavIcon(
              icon: navItem.icon,
              activeIcon: navItem.activeIcon,
              isSelected: true,
              theme: theme,
            ),
            label: navItem.label,
          );
        }).toList(),
      ),
    );
  }
}

/// 主页面容器，根据路由显示不同的页面
class MainContainerPage extends StatelessWidget {
  const MainContainerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final currentRoute = GoRouterState.of(context).uri.path;

        // 根据当前路由返回对应的页面
        return switch (currentRoute) {
          RoutePaths.home => const HomePage(),
          RoutePaths.bookshelf => const BookshelfPage(),
          RoutePaths.statistics => const StatisticsPage(),
          RoutePaths.profile => const ProfilePage(),
          _ => const HomePage(),
        };
      },
    );
  }
}
