import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/features/article/page/article_detail_page.dart';
import 'package:zephyr_reader/features/article/page/article_list_page.dart';
import 'package:zephyr_reader/features/auth/page/login_page.dart';
import 'package:zephyr_reader/features/bookshelf/page/book_detail_page.dart';
import 'package:zephyr_reader/features/bookshelf/page/bookshelf_page.dart';
import 'package:zephyr_reader/features/home/page/home_page.dart';
import 'package:zephyr_reader/features/home/page/splash_page.dart';
import 'package:zephyr_reader/features/main_layout.dart';
import 'package:zephyr_reader/features/profile/page/profile_page.dart';
import 'package:zephyr_reader/features/reader/page/reader_page_new.dart';
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
          name: RouteNames.bookDetail,
          path: RoutePaths.bookDetail,
          builder: (_, state) {
            final id = int.parse(state.pathParameters['id'] ?? '0');
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
          builder: (_, _) => ProfilePage(),
        ),

        // 文章列表路由
        GoRoute(
          name: RouteNames.articles,
          path: RoutePaths.articles,
          builder: (_, _) => ArticleListPage(),
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
        final bookId = int.parse(state.pathParameters['bookId'] ?? '0');
        final chapterId = int.parse(state.pathParameters['chapterId'] ?? '1');
        return ReaderPageNew(
          bookId: bookId,
          initialChapterId: chapterId,
          initialPageIndex: 0,
        );
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

/// 设置页面（占位）
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('阅读器设置'),
            subtitle: const Text('字体、主题、行间距等'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('功能开发中')));
            },
          ),
          ListTile(
            title: const Text('同步设置'),
            subtitle: const Text('云端同步、备份等'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('功能开发中')));
            },
          ),
          ListTile(
            title: const Text('关于'),
            subtitle: const Text('版本信息'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Zephyr Reader',
                applicationVersion: '1.0.0',
              );
            },
          ),
        ],
      ),
    );
  }
}
