import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
      width: isExtended ? 220 : 80,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildLogo(context, deviceType, theme),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
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
    ).animate().fadeIn(duration: 500.ms).slideX(begin: -0.05, end: 0);
  }

  Widget _buildLogo(
    BuildContext context,
    DeviceType deviceType,
    ThemeData theme,
  ) {
    final isExtended = deviceType == DeviceType.desktop;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_stories_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          if (isExtended) ...[
            const SizedBox(width: 12),
            Text(
              'Zephyr',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
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

    return GestureDetector(
      onTap: () => context.go(navItem.route),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.symmetric(
          horizontal: isExtended ? 16 : 0,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            SizedBox(width: isExtended ? 0 : 28),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isSelected ? navItem.activeIcon : navItem.icon,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                size: 22,
              ),
            ),
            if (isExtended) ...[
              const SizedBox(width: 12),
              Text(
                navItem.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
            if (isExtended) const Spacer(),
            if (isExtended && isSelected)
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
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
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('设置功能开发中')));
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.settings_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 22,
                ),
              ),
            ),
          ),
          if (isExtended) const SizedBox(width: 12),
          if (isExtended)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('通知功能开发中')));
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.notifications_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
                ),
              ),
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
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: NavigationBar(
          height: 72,
          selectedIndex: currentIndex,
          elevation: 0,
          indicatorColor: Colors.transparent,
          indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          onDestinationSelected: (index) {
            context.go(BottomNavItem.values[index].route);
          },
          destinations: BottomNavItem.values.map((navItem) {
            return NavigationDestination(
              icon: _buildNavIcon(
                context,
                navItem.icon,
                navItem.activeIcon,
                false,
                theme,
              ),
              selectedIcon: _buildNavIcon(
                context,
                navItem.icon,
                navItem.activeIcon,
                true,
                theme,
              ),
              label: navItem.label,
            );
          }).toList(),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildNavIcon(
    BuildContext context,
    IconData icon,
    IconData activeIcon,
    bool isSelected,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        isSelected ? activeIcon : icon,
        color: isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
        size: 22,
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
