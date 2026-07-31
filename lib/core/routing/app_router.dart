import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zephyr_reader/core/routing/not_found_page.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/features/bookshelf/page/book_detail_page.dart';
import 'package:zephyr_reader/features/bookshelf/page/bookshelf_page.dart';
import 'package:zephyr_reader/features/bookshelf/page/category_management_page.dart';
import 'package:zephyr_reader/features/bookshelf/page/wifi_transfer_page.dart';
import 'package:zephyr_reader/features/home/page/home_page.dart';
import 'package:zephyr_reader/features/home/page/splash_page.dart';
import 'package:zephyr_reader/features/learning_notes/page/learning_notes_page.dart';
import 'package:zephyr_reader/features/main_layout.dart';
import 'package:zephyr_reader/features/profile/page/about/about_page.dart';
import 'package:zephyr_reader/features/profile/page/dictionary/dictionary_settings_page.dart';
import 'package:zephyr_reader/features/profile/page/other/other_settings_page.dart';
import 'package:zephyr_reader/features/profile/page/profile/profile_page.dart';
import 'package:zephyr_reader/features/profile/page/theme/theme_brightness_page.dart';
import 'package:zephyr_reader/features/profile/page/tts/tts_settings_page.dart';
import 'package:zephyr_reader/features/profile/page/typography/typography_settings_page.dart';
import 'package:zephyr_reader/features/reader/page/reader_page.dart';
import 'package:zephyr_reader/features/search/page/book_search_page.dart';
import 'package:zephyr_reader/features/search/page/search_page.dart';
import 'package:zephyr_reader/features/statistics/page/reading_sessions_page.dart';
import 'package:zephyr_reader/features/statistics/page/statistics_page.dart';
import 'package:zephyr_reader/features/data/page/data_management_page.dart';
import 'package:zephyr_reader/features/vocabulary/page/vocabulary_page.dart';

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
    if (path == '/bookshelf') return AppRoute.bookshelf.path;
    if (path == '/vocabulary') return AppRoute.vocabulary.path;
    if (path == '/search') return AppRoute.search.path;
    return AppRoute.home.path;
  }
  return null;
}

final router = GoRouter(
  initialLocation: AppRoute.splash.path,
  debugLogDiagnostics: kDebugMode,

  redirect: (context, state) {
    final uri = state.uri;
    final deepLink = _resolveDeepLink(uri);
    if (deepLink != null) return deepLink;

    final location = state.matchedLocation;
    if (location == AppRoute.splash.path) return null;
    return null;
  },

  routes: [
    ShellRoute(
      builder: (context, state, child) => MainLayout(child: child),
      routes: [
        // 首页路由
        GoRoute(
          name: AppRoute.home.name,
          path: AppRoute.home.path,
          builder: (_, _) => const HomePage(),
        ),

        // 书架相关路由
        GoRoute(
          name: AppRoute.bookshelf.name,
          path: AppRoute.bookshelf.path,
          builder: (_, _) => const BookshelfPage(),
        ),
        GoRoute(
          name: AppRoute.categoryManagement.name,
          path: AppRoute.categoryManagement.path,
          builder: (_, _) => const CategoryManagementPage(),
        ),
        GoRoute(
          name: AppRoute.bookDetail.name,
          path: AppRoute.bookDetail.path,
          builder: (_, state) =>
              BookDetailPage(bookId: state.pathParameters['id'] ?? '0'),
        ),

        // 统计页面路由
        GoRoute(
          name: AppRoute.statistics.name,
          path: AppRoute.statistics.path,
          builder: (_, _) => const StatisticsPage(),
        ),

        // 个人中心路由
        GoRoute(
          name: AppRoute.profile.name,
          path: AppRoute.profile.path,
          builder: (_, _) => const ProfilePage(),
        ),
      ],
    ),

    // 个人中心设置子页面（独立页面，不使用 MainLayout）
    GoRoute(
      name: AppRoute.ttsSettings.name,
      path: AppRoute.ttsSettings.path,
      builder: (_, _) => const TtsSettingsPage(),
    ),
    GoRoute(
      name: AppRoute.dictionarySettings.name,
      path: AppRoute.dictionarySettings.path,
      builder: (_, _) => const DictionarySettingsPage(),
    ),
    GoRoute(
      name: AppRoute.typographySettings.name,
      path: AppRoute.typographySettings.path,
      builder: (_, _) => const TypographySettingsPage(),
    ),
    GoRoute(
      name: AppRoute.themeBrightness.name,
      path: AppRoute.themeBrightness.path,
      builder: (_, _) => const ThemeBrightnessPage(),
    ),
    GoRoute(
      name: AppRoute.otherSettings.name,
      path: AppRoute.otherSettings.path,
      builder: (_, _) => const OtherSettingsPage(),
    ),
    GoRoute(
      name: AppRoute.about.name,
      path: AppRoute.about.path,
      builder: (_, _) => const AboutPage(),
    ),

    // 阅读器路由（独立页面，不使用 MainLayout）
    GoRoute(
      name: AppRoute.reader.name,
      path: AppRoute.reader.path,
      pageBuilder: (context, state) {
        final bookId = state.pathParameters['bookId'] ?? '0';
        return CustomTransitionPage<void>(
          key: state.pageKey,
          child: ReaderPage(bookId: bookId),
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
      name: AppRoute.search.name,
      path: AppRoute.search.path,
      builder: (_, _) => SearchPage(),
    ),

    // 同步相关路由
    GoRoute(
      name: AppRoute.dataManagement.name,
      path: AppRoute.dataManagement.path,
      builder: (_, _) => const DataManagementPage(),
    ),

    // 全书搜索
    GoRoute(
      name: AppRoute.bookSearch.name,
      path: AppRoute.bookSearch.path,
      builder: (_, state) {
        final bookId = state.uri.queryParameters['bookId'] ?? '';
        return BookSearchPage(bookId: bookId);
      },
    ),

    // 笔记管理

    // 生词本
    GoRoute(
      name: AppRoute.vocabulary.name,
      path: AppRoute.vocabulary.path,
      builder: (_, _) => const VocabularyPage(),
    ),

    // 学习与笔记
    GoRoute(
      name: AppRoute.learningNotes.name,
      path: AppRoute.learningNotes.path,
      builder: (_, _) => const LearningNotesPage(),
    ),

    // 阅读会话历史
    GoRoute(
      name: AppRoute.readingSessions.name,
      path: AppRoute.readingSessions.path,
      builder: (_, _) => const ReadingSessionsPage(),
    ),

    // WiFi 传书
    GoRoute(
      name: AppRoute.wifiTransfer.name,
      path: AppRoute.wifiTransfer.path,
      builder: (_, _) => const WifiTransferPage(),
    ),

    // Splash 页面（独立页面，不使用 MainLayout）
    GoRoute(
      name: AppRoute.splash.name,
      path: AppRoute.splash.path,
      builder: (_, _) => const SplashPage(),
    ),
  ],

  errorBuilder: (context, state) => NotFoundPage(path: state.uri.path),
);
