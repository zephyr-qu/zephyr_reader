import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/features/bookshelf/page/bookshelf_page.dart';
import 'package:zephyr_reader/features/home/page/home_page.dart';
import 'package:zephyr_reader/features/profile/page/profile_page.dart';
import 'package:zephyr_reader/features/statistics/page/statistics_page.dart';
import 'package:zephyr_reader/shared/widget/adaptive_layout.dart';

/// 底部导航栏配
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
}

/// 带自适应导航栏的主布局
/// 手机：底NavigationBar
/// 平板：NavigationRail 侧边
class MainLayout extends StatefulWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).uri.path;
    final deviceType = LayoutBreakpoints.getDeviceType(context);
    final isTabletOrDesktop =
        deviceType == DeviceType.tablet || deviceType == DeviceType.desktop;
    final theme = Theme.of(context);

    // 根据当前路由更新选中的索
    for (var i = 0; i < BottomNavItem.values.length; i++) {
      if (currentRoute == BottomNavItem.values[i].route) {
        _currentIndex = i;
        break;
      }
    }

    if (isTabletOrDesktop) {
      // 平板/桌面：使NavigationRail 侧边栏布局
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: deviceType == DeviceType.desktop,
              minWidth: 80,
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                final navItem = BottomNavItem.values[index];
                context.go(navItem.route);
              },
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
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
                      Icon(
                        Icons.auto_stories,
                        color: theme.colorScheme.onPrimary,
                        size: 24,
                      ),
                      if (deviceType == DeviceType.desktop) ...[
                        const SizedBox(width: 8),
                        Text(
                          'Zephyr',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              destinations: BottomNavItem.values.map((navItem) {
                return NavigationRailDestination(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(navItem.icon),
                  ),
                  selectedIcon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      navItem.activeIcon,
                      color: theme.colorScheme.primary,
                    ),
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
      // 手机：使NavigationBar 底部导航
      return Scaffold(
        body: widget.child,
        extendBody: true,
        bottomNavigationBar: Container(
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
            selectedIndex: _currentIndex,
            elevation: 0,
            shadowColor: theme.colorScheme.primary.withValues(alpha: 0.15),
            onDestinationSelected: (index) {
              final navItem = BottomNavItem.values[index];
              context.go(navItem.route);
            },
            destinations: BottomNavItem.values.map((navItem) {
              return NavigationDestination(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(navItem.icon),
                ),
                selectedIcon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    navItem.activeIcon,
                    color: theme.colorScheme.primary,
                  ),
                ),
                label: navItem.label,
              );
            }).toList(),
          ),
        ),
      );
    }
  }
}

/// 主页面容器，根据路由显示不同的页
class MainContainerPage extends StatelessWidget {
  const MainContainerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final currentRoute = GoRouterState.of(context).uri.path;

        // 根据当前路由返回对应的页
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
