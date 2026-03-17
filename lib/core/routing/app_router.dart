import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/features/article/page/article_list_page.dart';
import 'package:zephyr_reader/features/auth/page/login_page.dart';
import 'package:zephyr_reader/features/bookshelf/page/book_detail_page.dart';
import 'package:zephyr_reader/features/bookshelf/page/bookshelf_page.dart';
import 'package:zephyr_reader/features/home/page/main_page.dart';
import 'package:zephyr_reader/features/profile/page/profile_page.dart';
import 'package:zephyr_reader/features/reader/page/reader_page_new.dart';
import 'package:zephyr_reader/features/search/page/search_page.dart';
import 'package:signals_hooks/signals_hooks.dart';

final isAuthenticated = signal<bool>(false, autoDispose: true);
void login() => isAuthenticated.value = true;
void logout() => isAuthenticated.value = false;

final _protectedPaths = {RoutePaths.home};

final router = GoRouter(
  initialLocation: RoutePaths.splash,
  debugLogDiagnostics: true,
  refreshListenable: isAuthenticated,

  redirect: (context, state) {
    final location = state.uri.path;
    final isLoggedIn = isAuthenticated.value;

    if (isLoggedIn && location == RoutePaths.login) return RoutePaths.home;

    if (!isLoggedIn && _protectedPaths.contains(location)) {
      return RoutePaths.login;
    }
    return null;
  },

  routes: [
    GoRoute(
      name: RouteNames.login,
      path: RoutePaths.login,
      builder: (_, _) => const LoginPage(),
    ),
    GoRoute(
      name: RouteNames.home,
      path: RoutePaths.home,
      builder: (_, _) => MainPage(child: Container()),
    ),
    GoRoute(
      name: RouteNames.splash,
      path: RoutePaths.splash,
      builder: (_, _) => MainPage(child: Container()),
    ),
    GoRoute(
      name: RouteNames.profile,
      path: RoutePaths.profile,
      builder: (_, _) => ProfilePage(),
    ),
    GoRoute(
      name: RouteNames.articles,
      path: RoutePaths.articles,
      builder: (_, _) => ArticleListPage(),
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
        final id =  int.parse(state.pathParameters['id'] ?? '0');
        return BookDetailPage(bookId: id);
      },
    ),
    // 阅读器路由
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
    // 搜索路由
    GoRoute(
      name: RouteNames.search,
      path: RoutePaths.search,
      builder: (_, _) => const SearchPage(),
    ),
    // 设置路由
    GoRoute(
      name: RouteNames.settings,
      path: RoutePaths.settings,
      builder: (_, _) => const SettingsPage(),
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
