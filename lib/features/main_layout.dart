import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/features/bookshelf/page/bookshelf_page.dart';
import 'package:zephyr_reader/features/home/page/home_page.dart';
import 'package:zephyr_reader/features/profile/page/profile_page.dart';
import 'package:zephyr_reader/features/statistics/page/statistics_page.dart';
import 'package:zephyr_reader/core/presentation/widgets/adaptive_layout.dart';

/// 底部导航栏配置
enum BottomNavItem {
  home(
    label: '首页',
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    route: RoutePaths.home,
    routeName: RouteNames.home,
  ),
  bookshelf(
    label: '书籍',
    icon: Icons.book_outlined,
    activeIcon: Icons.book_rounded,
    route: RoutePaths.bookshelf,
    routeName: RouteNames.bookshelf,
  ),
  statistics(
    label: '统计',
    icon: Icons.bar_chart_outlined,
    activeIcon: Icons.bar_chart_rounded,
    route: RoutePaths.statistics,
    routeName: RouteNames.statistics,
  ),
  profile(
    label: '我的',
    icon: Icons.person_outline,
    activeIcon: Icons.person_rounded,
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

    final currentIndex = _calculateSelectedIndex(currentRoute);

    if (isTabletOrDesktop) {
      return Scaffold(
        body: Row(
          children: [
            _buildSideBar(context, deviceType, currentIndex, theme),
            VerticalDivider(
              thickness: 1,
              width: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: widget.child,
              ),
            ),
          ],
        ),
      );
    } else {
      return Scaffold(
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: widget.child,
        ),
        extendBody: true,
        bottomNavigationBar: _buildBottomNavigationBar(
          context,
          currentIndex,
          theme,
        ),
      );
    }
  }

  Widget _buildSideBar(
    BuildContext context,
    DeviceType deviceType,
    int currentIndex,
    ThemeData theme,
  ) {
    final isExtended = deviceType == DeviceType.desktop;

    return Container(
      width: isExtended ? 200 : 72,
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: DesignTokens.divider, width: 0.5),
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

  Widget _buildLogo(
    BuildContext context,
    DeviceType deviceType,
    ThemeData theme,
  ) {
    final isExtended = deviceType == DeviceType.desktop;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 24, horizontal: isExtended ? 16 : 12),
      child: Row(
        children: [
          Icon(
            Icons.auto_stories_rounded,
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

    return GestureDetector(
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
              Text(
                navItem.label,
                style: TextStyle(
                  fontSize: 14,
                  color: isSelected ? activeColor : inactiveColor,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions(
    BuildContext context,
    ThemeData theme,
    bool isExtended,
  ) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.settings_outlined,
              color: theme.colorScheme.onSurfaceVariant, size: 20),
            onPressed: () {},
            tooltip: '设置',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar(
    BuildContext context,
    int currentIndex,
    ThemeData theme,
  ) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: DesignTokens.divider, width: 0.5),
        ),
      ),
      child: SafeArea(
        child: NavigationBar(
          height: 56,
          selectedIndex: currentIndex,
          elevation: 0,
          indicatorColor: Colors.transparent,
          backgroundColor: theme.colorScheme.surface,
          onDestinationSelected: (index) {
            context.go(BottomNavItem.values[index].route);
          },
          destinations: BottomNavItem.values.map((navItem) {
            return NavigationDestination(
              icon: Icon(navItem.icon, size: 22),
              selectedIcon: Icon(navItem.activeIcon, size: 22),
              label: navItem.label,
            );
          }).toList(),
        ),
      ),
    );
  }

  int _calculateSelectedIndex(String currentRoute) {
    for (var i = 0; i < BottomNavItem.values.length; i++) {
      if (BottomNavItem.values[i].matchesRoute(currentRoute)) {
        return i;
      }
    }
    return 0;
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
