import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/features/article/page/article_detail_page.dart';
import 'package:zephyr_reader/features/article/page/article_list_page.dart';
import 'package:zephyr_reader/features/auth/page/login_page.dart';
import 'package:zephyr_reader/features/bookshelf/page/book_detail_page.dart';
import 'package:zephyr_reader/features/bookshelf/page/bookshelf_page.dart';
import 'package:zephyr_reader/features/bookshelf/page/category_management_page.dart';
import 'package:zephyr_reader/features/home/page/home_page.dart';
import 'package:zephyr_reader/features/home/page/splash_page.dart';
import 'package:zephyr_reader/features/main_layout.dart';
import 'package:zephyr_reader/features/profile/page/about_page.dart';
import 'package:zephyr_reader/features/profile/page/app_settings_page.dart';
import 'package:zephyr_reader/features/profile/page/profile_page.dart';
import 'package:zephyr_reader/features/profile/page/reading_settings_page.dart';
import 'package:zephyr_reader/features/profile/page/theme_settings_page.dart';
import 'package:zephyr_reader/features/reader/page/reader_page.dart';
import 'package:zephyr_reader/features/search/page/search_page.dart';
import 'package:zephyr_reader/features/statistics/page/statistics_page.dart';

final isAuthenticated = signal<bool>(false, autoDispose: true);
void login() => isAuthenticated.value = true;
void logout() => isAuthenticated.value = false;

// final _protectedPaths = {
//   RoutePaths.home,
//   RoutePaths.bookshelf,
//   RoutePaths.statistics,
//   RoutePaths.profile,
// };

final router = GoRouter(
  initialLocation: RoutePaths.splash,
  debugLogDiagnostics: true,
  refreshListenable: isAuthenticated,

  redirect: (context, state) {
    final location = state.uri.path;
    // final isLoggedIn = isAuthenticated.value;
    final isLoggedIn = true;

    // 已登录时访问登录页，重定向到首页
    if (isLoggedIn && location == RoutePaths.login) {
      return RoutePaths.home;
    }

    // 未登录时访问受保护路径，重定向到登录页
    // if (!isLoggedIn && _protectedPaths.contains(location)) {
    //   return RoutePaths.login;
    // }
    return null;
  },

  routes: [
    // 登录页面（独立页面，不使用 MainLayout）
    GoRoute(
      name: RouteNames.login,
      path: RoutePaths.login,
      builder: (_, _) => const LoginPage(),
    ),

    // 使用 ShellRoute 包装主布局，实现底部导航栏/侧边导航栏
    ShellRoute(
      builder: (context, state, child) => MainLayout(child: child),
      routes: [
        // 首页路由
        GoRoute(
          name: RouteNames.home,
          path: RoutePaths.home,
          builder: (_, _) => const HomePage(),
        ),

        // 书架相关路由
        GoRoute(
          name: RouteNames.bookshelf,
          path: RoutePaths.bookshelf,
          builder: (_, _) => const BookshelfPage(),
        ),
        GoRoute(
          name: RouteNames.categoryManagement,
          path: RoutePaths.categoryManagement,
          builder: (_, _) => const CategoryManagementPage(),
        ),
        GoRoute(
          name: RouteNames.bookDetail,
          path: RoutePaths.bookDetail,
          builder: (_, state) {
            final id = state.pathParameters['id'] ?? '0';
            return BookDetailPage(bookId: id);
          },
        ),

        // 统计页面路由
        GoRoute(
          name: RouteNames.statistics,
          path: RoutePaths.statistics,
          builder: (_, _) => const StatisticsPage(),
        ),

        // 个人中心路由
        GoRoute(
          name: RouteNames.profile,
          path: RoutePaths.profile,
          builder: (_, _) => const ProfilePage(),
        ),

        // 设置相关路由
        GoRoute(
          name: RouteNames.readingSettings,
          path: RoutePaths.readingSettings,
          builder: (_, _) => const ReadingSettingsPage(),
        ),
        GoRoute(
          name: RouteNames.appSettings,
          path: RoutePaths.appSettings,
          builder: (_, _) => const AppSettingsPage(),
        ),
        GoRoute(
          name: RouteNames.about,
          path: RoutePaths.about,
          builder: (_, _) => const AboutPage(),
        ),

        // 文章列表路由
        GoRoute(
          name: RouteNames.articles,
          path: RoutePaths.articles,
          builder: (_, _) => const ArticleListPage(),
        ),
        GoRoute(
          name: RouteNames.articleDetail,
          path: RoutePaths.articleDetail,
          builder: (_, state) {
            final id = int.parse(state.pathParameters['id'] ?? '0');
            return ArticleDetailPage(articleId: id);
          },
        ),
      ],
    ),

    // 阅读器路由（独立页面，不使用 MainLayout）
    GoRoute(
      name: RouteNames.reader,
      path: RoutePaths.reader,
      builder: (_, state) {
        final bookId = state.pathParameters['bookId'] ?? '0';
        final chapterId = int.parse(state.pathParameters['chapterId'] ?? '1');
        return ReaderPage(bookId: bookId, initialChapterId: chapterId);
      },
    ),

    // 搜索路由（独立页面，不使用 MainLayout）
    GoRoute(
      name: RouteNames.search,
      path: RoutePaths.search,
      builder: (_, _) => const SearchPage(),
    ),

    // 设置路由（独立页面，不使用 MainLayout）
    GoRoute(
      name: RouteNames.settings,
      path: RoutePaths.settings,
      builder: (_, _) => const SettingsPage(),
    ),

    // 主题设置路由
    GoRoute(
      name: RouteNames.themeSettings,
      path: RoutePaths.themeSettings,
      builder: (_, _) => const ThemeSettingsPage(),
    ),

    // Splash 页面（独立页面，不使用 MainLayout）
    GoRoute(
      name: RouteNames.splash,
      path: RoutePaths.splash,
      builder: (_, _) => const SplashPage(),
    ),
  ],

  errorBuilder: (context, state) => NotFoundPage(path: state.uri.path),
);

class NotFoundPage extends StatelessWidget {
  final String path;

  const NotFoundPage({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('页面未找到')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('未找到页面: $path'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(RoutePaths.bookshelf),
              child: const Text('返回书架'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 设置页面
///
/// 提供统一的设置入口，包含：
/// - 阅读设置
/// - 主题设置
/// - 应用设置
/// - 关于页面
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('设置'), elevation: 0),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // 阅读设置
          _buildSettingsSection(
            context,
            icon: Icons.menu_book,
            title: '阅读设置',
            subtitle: '字体、字号、翻页模式等',
            onTap: () => context.push(RoutePaths.readingSettings),
          ),

          // 主题设置
          _buildSettingsSection(
            context,
            icon: Icons.palette,
            title: '主题设置',
            subtitle: '浅色、深色、纯黑、护眼模式',
            onTap: () => context.push(RoutePaths.themeSettings),
          ),

          // 应用设置
          _buildSettingsSection(
            context,
            icon: Icons.settings_applications,
            title: '应用设置',
            subtitle: '语言、同步、存储、备份',
            onTap: () => context.push(RoutePaths.appSettings),
          ),

          const SizedBox(height: 24),

          // 其他设置
          _buildSettingsSection(
            context,
            icon: Icons.info_outline,
            title: '关于',
            subtitle: '版本信息、用户协议、隐私政策',
            onTap: () => context.push(RoutePaths.about),
          ),

          // 版本信息
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.auto_stories,
                    size: 48,
                    color: theme.colorScheme.primary.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Zephyr Reader',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '版本 1.0.0',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: theme.colorScheme.onPrimaryContainer,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
        ),
        onTap: onTap,
      ),
    );
  }
}
