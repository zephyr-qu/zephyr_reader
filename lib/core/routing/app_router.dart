import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/article/application/article_view_model.dart';
import 'package:zephyr_reader/features/article/page/article_detail_page.dart';
import 'package:zephyr_reader/features/article/page/article_list_page.dart';
import 'package:zephyr_reader/features/bookshelf/application/bookshelf_view_model.dart';
import 'package:zephyr_reader/features/bookshelf/application/book_detail_view_model.dart';
import 'package:zephyr_reader/features/bookshelf/page/book_detail_page.dart';
import 'package:zephyr_reader/features/bookshelf/page/bookshelf_page.dart';
import 'package:zephyr_reader/features/bookshelf/page/category_management_page.dart';
import 'package:zephyr_reader/features/bookshelf/page/wifi_transfer_page.dart';
import 'package:zephyr_reader/features/home/application/home_view_model.dart';
import 'package:zephyr_reader/features/home/page/home_page.dart';
import 'package:zephyr_reader/features/learning_notes/application/learning_notes_view_model.dart';
import 'package:zephyr_reader/features/learning_notes/page/learning_notes_page.dart';
import 'package:zephyr_reader/features/home/page/splash_page.dart';
import 'package:zephyr_reader/features/main_layout.dart';
import 'package:zephyr_reader/features/profile/application/profile_view_model.dart';
import 'package:zephyr_reader/features/profile/page/about_page.dart';
import 'package:zephyr_reader/features/profile/page/profile_page.dart';
import 'package:zephyr_reader/features/profile/page/tts_settings_page.dart';
import 'package:zephyr_reader/features/profile/page/typography_settings_page.dart';
import 'package:zephyr_reader/features/profile/page/theme_brightness/theme_brightness_page.dart';
import 'package:zephyr_reader/features/profile/page/theme_brightness/theme_brightness_view_model.dart';
import 'package:zephyr_reader/features/profile/page/other_settings/other_settings_page.dart';
import 'package:zephyr_reader/features/profile/page/other_settings/other_settings_view_model.dart';
import 'package:zephyr_reader/features/reader/application/reader_view_model.dart';
import 'package:zephyr_reader/features/reader/page/reader_page.dart';
import 'package:zephyr_reader/features/reader/page/note_manage_page.dart';
import 'package:zephyr_reader/features/reader/page/bookmark_manage_page.dart';
import 'package:zephyr_reader/features/search/application/search_view_model.dart';
import 'package:zephyr_reader/features/search/page/search_page.dart';
import 'package:zephyr_reader/features/search/page/book_search_page.dart';
import 'package:zephyr_reader/features/vocabulary/application/vocabulary_view_model.dart';
import 'package:zephyr_reader/features/statistics/application/statistics_view_model.dart';
import 'package:zephyr_reader/features/statistics/page/statistics_page.dart';
import 'package:zephyr_reader/features/statistics/application/reading_stats_service.dart';
import 'package:zephyr_reader/features/statistics/page/reading_stats_page.dart';
import 'package:zephyr_reader/shared/widget/not_found_page.dart';
import 'package:zephyr_reader/features/sync/page/webdav_settings_page.dart';
import 'package:zephyr_reader/features/sync/page/sync_history_page.dart';
import 'package:zephyr_reader/features/sync/page/storage_sync_page.dart';
import 'package:zephyr_reader/features/sync/page/backup_restore_page.dart';
import 'package:zephyr_reader/features/vocabulary/page/vocabulary_page.dart';
import 'package:zephyr_reader/features/statistics/page/reading_sessions_page.dart';
import 'package:zephyr_reader/features/reader/page/cache_manage_page.dart';
import 'package:zephyr_reader/features/reader/data/repositories/rust_reader_repository.dart';
import 'package:zephyr_reader/core/reader/tts_service.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/core/reader/custom_font_service.dart';

/// 解析深度链接 URI，返回重定向路径
String? _resolveDeepLink(Uri uri) {
  if (uri.scheme == 'zephyr' || uri.host == 'zephyr.app') {
    final path = uri.path == '/' ? uri.fragment : uri.path;
    if (path.startsWith('/reader/')) {
      final parts = path.split('/');
      if (parts.length >= 3) {
        final bookId = parts[2];
        final chapterId = parts.length > 3 ? parts[3] : '0';
        return '/reader/$bookId/$chapterId';
      }
    }
    if (path == '/bookshelf') return RoutePaths.bookshelf;
    if (path == '/vocabulary') return RoutePaths.vocabulary;
    if (path == '/search') return RoutePaths.search;
    return RoutePaths.home;
  }
  return null;
}

final router = GoRouter(
  initialLocation: RoutePaths.splash,
  debugLogDiagnostics: kDebugMode,

  redirect: (context, state) {
    final uri = state.uri;
    final deepLink = _resolveDeepLink(uri);
    if (deepLink != null) return deepLink;

    final location = state.matchedLocation;
    if (location == RoutePaths.splash) return null;

    return null;
  },

  routes: [
    ShellRoute(
      builder: (context, state, child) => MainLayout(child: child),
      routes: [
        // 首页路由
        GoRoute(
          name: RouteNames.home,
          path: RoutePaths.home,
          builder: (_, _) => HomePage(vm: getIt<HomeViewModel>()),
        ),

        // 书架相关路由
        GoRoute(
          name: RouteNames.bookshelf,
          path: RoutePaths.bookshelf,
          builder: (_, _) => BookshelfPage(vm: GetIt.I<BookshelfViewModel>()),
        ),
        GoRoute(
          name: RouteNames.categoryManagement,
          path: RoutePaths.categoryManagement,
          builder: (_, _) =>
              CategoryManagementPage(vm: GetIt.I<BookshelfViewModel>()),
        ),
        GoRoute(
          name: RouteNames.bookDetail,
          path: RoutePaths.bookDetail,
          builder: (_, state) => BookDetailPage(
            vm: getIt<BookDetailViewModel>(
              param1: state.pathParameters['id'] ?? '0',
            ),
          ),
        ),

        // 统计页面路由
        GoRoute(
          name: RouteNames.statistics,
          path: RoutePaths.statistics,
          builder: (_, _) => StatisticsPage(vm: getIt<StatisticsViewModel>()),
        ),

        // 个人中心路由
        GoRoute(
          name: RouteNames.profile,
          path: RoutePaths.profile,
          builder: (_, _) => ProfilePage(vm: GetIt.I<ProfileViewModel>()),
        ),

        // 设置相关路由
        GoRoute(
          name: RouteNames.ttsSettings,
          path: RoutePaths.ttsSettings,
          builder: (_, _) => TtsSettingsPage(tts: getIt<TtsService>()),
        ),
        GoRoute(
          name: RouteNames.typographySettings,
          path: RoutePaths.typographySettings,
          builder: (_, _) => TypographySettingsPage(
            config: getIt<ReaderConfig>(),
            fontRepo: getIt<FontRepository>(),
          ),
        ),
        GoRoute(
          name: RouteNames.themeBrightness,
          path: RoutePaths.themeBrightness,
          builder: (_, _) =>
              ThemeBrightnessPage(vm: getIt<ThemeBrightnessViewModel>()),
        ),
        GoRoute(
          name: RouteNames.otherSettings,
          path: RoutePaths.otherSettings,
          builder: (_, _) =>
              OtherSettingsPage(vm: getIt<OtherSettingsViewModel>()),
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
          builder: (_, _) => ArticleListPage(vm: GetIt.I<ArticleViewModel>()),
        ),
        GoRoute(
          name: RouteNames.articleDetail,
          path: RoutePaths.articleDetail,
          builder: (_, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
            return ArticleDetailPage(
              articleId: id,
              vm: getIt<ArticleViewModel>(),
            );
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
        final chapterId =
            int.tryParse(state.pathParameters['chapterId'] ?? '') ?? 0;
        return ReaderPage(
          vm: GetIt.I<ReaderViewModel>(),
          bookId: bookId,
          initialChapterId: chapterId,
        );
      },
    ),

    // 搜索路由（独立页面，不使用 MainLayout）
    GoRoute(
      name: RouteNames.search,
      path: RoutePaths.search,
      builder: (_, _) => SearchPage(vm: GetIt.I<SearchViewModel>()),
    ),

    // 同步相关路由
    GoRoute(
      name: RouteNames.sync,
      path: RoutePaths.sync,
      builder: (_, _) => const WebDavSettingsPage(),
    ),
    GoRoute(
      name: RouteNames.storageSync,
      path: RoutePaths.storageSync,
      builder: (_, _) => const StorageSyncPage(),
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
      builder: (_, state) {
        final bookId = state.uri.queryParameters['bookId'] ?? '';
        return BookSearchPage(bookId: bookId);
      },
    ),

    // 阅读统计详情
    GoRoute(
      name: RouteNames.readingStats,
      path: RoutePaths.readingStats,
      builder: (_, _) => ReadingStatsPage(vm: GetIt.I<ReadingStatsViewModel>()),
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

    // 生词本
    GoRoute(
      name: RouteNames.vocabulary,
      path: RoutePaths.vocabulary,
      builder: (_, _) => VocabularyPage(vm: GetIt.I<VocabularyViewModel>()),
    ),

    // 学习与笔记
    GoRoute(
      name: RouteNames.learningNotes,
      path: RoutePaths.learningNotes,
      builder: (_, _) =>
          LearningNotesPage(vm: GetIt.I<LearningNotesViewModel>()),
    ),

    // 阅读会话历史
    GoRoute(
      name: RouteNames.readingSessions,
      path: RoutePaths.readingSessions,
      builder: (_, _) => const ReadingSessionsPage(),
    ),

    // 缓存管理
    GoRoute(
      name: RouteNames.cacheManage,
      path: RoutePaths.cacheManage,
      builder: (_, _) => CacheManagePage(repo: getIt<ReaderRepository>()),
    ),

    // WiFi 传书
    GoRoute(
      name: RouteNames.wifiTransfer,
      path: RoutePaths.wifiTransfer,
      builder: (_, _) => const WifiTransferPage(),
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
