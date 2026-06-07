import 'package:flutter/material.dart';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/features/bookshelf/page/book_detail_page.dart';
import 'package:zephyr_reader/features/bookshelf/page/bookshelf_page.dart';
import 'package:zephyr_reader/features/bookshelf/page/category_management_page.dart';
import 'package:zephyr_reader/features/bookshelf/page/wifi_transfer_page.dart';
import 'package:zephyr_reader/features/home/page/home_page.dart';
import 'package:zephyr_reader/features/learning_notes/page/learning_notes_page.dart';
import 'package:zephyr_reader/features/home/page/splash_page.dart';
import 'package:zephyr_reader/features/main_layout.dart';
import 'package:zephyr_reader/features/profile/page/about/about_page.dart';
import 'package:zephyr_reader/features/profile/page/profile/profile_page.dart';
import 'package:zephyr_reader/features/profile/page/tts/tts_settings_page.dart';
import 'package:zephyr_reader/features/profile/page/typography/typography_settings_page.dart';
import 'package:zephyr_reader/features/profile/page/theme/theme_brightness_page.dart';
import 'package:zephyr_reader/features/profile/page/other/other_settings_page.dart';
import 'package:zephyr_reader/features/reader/page/reader_page.dart';
import 'package:zephyr_reader/features/reader/page/bookmark_manage_page.dart';
import 'package:zephyr_reader/features/search/page/search_page.dart';
import 'package:zephyr_reader/features/search/page/book_search_page.dart';
import 'package:zephyr_reader/features/statistics/page/statistics_page.dart';
import 'package:zephyr_reader/core/routing/not_found_page.dart';
import 'package:zephyr_reader/features/sync/page/storage_sync_page.dart';
import 'package:zephyr_reader/features/vocabulary/page/vocabulary_page.dart';
import 'package:zephyr_reader/features/statistics/page/reading_sessions_page.dart';
import 'package:zephyr_reader/features/reader/page/cache_manage_page.dart';

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
          builder: (_, state) =>
              BookDetailPage(bookId: state.pathParameters['id'] ?? '0'),
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
          name: RouteNames.ttsSettings,
          path: RoutePaths.ttsSettings,
          builder: (_, _) => const TtsSettingsPage(),
        ),
        GoRoute(
          name: RouteNames.typographySettings,
          path: RoutePaths.typographySettings,
          builder: (_, _) => const TypographySettingsPage(),
        ),
        GoRoute(
          name: RouteNames.themeBrightness,
          path: RoutePaths.themeBrightness,
          builder: (_, _) => ThemeBrightnessPage(),
        ),
        GoRoute(
          name: RouteNames.otherSettings,
          path: RoutePaths.otherSettings,
          builder: (_, _) => OtherSettingsPage(),
        ),
        GoRoute(
          name: RouteNames.about,
          path: RoutePaths.about,
          builder: (_, _) => const AboutPage(),
        ),
      ],
    ),

    // 阅读器路由（独立页面，不使用 MainLayout）
    GoRoute(
      name: RouteNames.reader,
      path: RoutePaths.reader,
      pageBuilder: (context, state) {
        final bookId = state.pathParameters['bookId'] ?? '0';
        final chapterId =
            int.tryParse(state.pathParameters['chapterId'] ?? '') ?? 0;
        final pageIndex =
            int.tryParse(state.uri.queryParameters['page'] ?? '') ?? 0;
        return CustomTransitionPage<void>(
          key: state.pageKey,
          child: ReaderPage(
            bookId: bookId,
            initialChapterId: chapterId,
            initialPageIndex: pageIndex,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // 前进: 上滑 + 淡入 + 微微放大（翻书）
            // 返回: 下滑 + 淡出 + 缩小到 96%（合书）
            return ScaleTransition(
              scale: Tween<double>(begin: 1, end: 0.96)
                  .chain(CurveTween(curve: Curves.easeInCubic))
                  .animate(secondaryAnimation),
              child: SlideTransition(
                position:
                    Tween<Offset>(
                          begin: const Offset(0, 0.04),
                          end: Offset.zero,
                        )
                        .chain(CurveTween(curve: Curves.easeOutCubic))
                        .animate(animation),
                child: FadeTransition(
                  opacity: Tween<double>(begin: 0.3, end: 1).animate(animation),
                  child: child,
                ),
              ),
            );
          },
        );
      },
    ),

    // 搜索路由（独立页面，不使用 MainLayout）
    GoRoute(
      name: RouteNames.search,
      path: RoutePaths.search,
      builder: (_, _) => SearchPage(),
    ),

    // 同步相关路由
    GoRoute(
      name: RouteNames.storageSync,
      path: RoutePaths.storageSync,
      builder: (_, _) => const StorageSyncPage(),
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

    // 笔记管理

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
      builder: (_, _) => const VocabularyPage(),
    ),

    // 学习与笔记
    GoRoute(
      name: RouteNames.learningNotes,
      path: RoutePaths.learningNotes,
      builder: (_, _) => const LearningNotesPage(),
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
      builder: (_, _) => const CacheManagePage(),
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
