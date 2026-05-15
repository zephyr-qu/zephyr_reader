import 'package:go_router/go_router.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/features/article/page/article_detail_page.dart';
import 'package:zephyr_reader/features/article/page/article_list_page.dart';
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
import 'package:zephyr_reader/features/reader/page/note_manage_page.dart';
import 'package:zephyr_reader/features/reader/page/bookmark_manage_page.dart';
import 'package:zephyr_reader/features/search/page/search_page.dart';
import 'package:zephyr_reader/features/search/page/book_search_page.dart';
import 'package:zephyr_reader/features/statistics/page/statistics_page.dart';
import 'package:zephyr_reader/features/statistics/page/reading_stats_page.dart';
import 'package:zephyr_reader/shared/widget/not_found_page.dart';
import 'package:zephyr_reader/features/profile/page/settings_page.dart';
import 'package:zephyr_reader/features/sync/page/webdav_settings_page.dart';
import 'package:zephyr_reader/features/sync/page/sync_history_page.dart';
import 'package:zephyr_reader/features/sync/page/backup_restore_page.dart';

final router = GoRouter(
  initialLocation: RoutePaths.splash,
  debugLogDiagnostics: true,

  routes: [
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

    // 同步相关路由
    GoRoute(
      name: RouteNames.sync,
      path: RoutePaths.sync,
      builder: (_, _) => const WebDavSettingsPage(),
    ),
    GoRoute(
      name: RouteNames.syncHistory,
      path: RoutePaths.syncHistory,
      builder: (_, _) => const SyncHistoryPage(),
    ),
    GoRoute(
      name: RouteNames.backupRestore,
      path: RoutePaths.backupRestore,
      builder: (_, _) => const BackupRestorePage(),
    ),

    // 全书搜索
    GoRoute(
      name: RouteNames.bookSearch,
      path: RoutePaths.bookSearch,
      builder: (_, _) => const BookSearchPage(),
    ),

    // 阅读统计详情
    GoRoute(
      name: RouteNames.readingStats,
      path: RoutePaths.readingStats,
      builder: (_, _) => const ReadingStatsPage(),
    ),

    // 笔记管理
    GoRoute(
      name: RouteNames.noteManage,
      path: RoutePaths.noteManage,
      builder: (_, state) {
        final bookId = state.pathParameters['bookId'] ?? '';
        final bookTitle = state.uri.queryParameters['title'] ?? '';
        return NoteManagePage(bookId: bookId, bookTitle: bookTitle);
      },
    ),

    // 书签管理
    GoRoute(
      name: RouteNames.bookmarkManage,
      path: RoutePaths.bookmarkManage,
      builder: (_, state) {
        final bookId = state.pathParameters['bookId'] ?? '';
        return BookmarkManagePage(bookId: bookId);
      },
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
