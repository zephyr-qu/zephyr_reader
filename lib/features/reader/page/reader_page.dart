/// 阅读器页面
///
/// 功能：
/// - 支持上下滚动和左右翻页模式
/// - 章节内容加载与显示
/// - 自动保存阅读进度
/// - 章节跳转
/// - 阅读设置（字体、间距、主题）
/// - 书签功能
library;

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../application/reader_view_model.dart';
import 'widgets/reader_content.dart';
import 'widgets/reader_toolbar.dart';
import 'widgets/reader_bottom_toolbar.dart';
import 'widgets/chapter_list_widget.dart';
import 'widgets/reader_settings_panel.dart';
import 'widgets/bookmark_widget.dart';

/// 阅读器页面
class ReaderPage extends StatelessWidget {
  /// 书籍 ID
  final String bookId;

  /// 初始章节 ID
  final int initialChapterId;

  const ReaderPage({
    super.key,
    required this.bookId,
    this.initialChapterId = 0,
  });

  @override
  Widget build(BuildContext context) {
    final vm = GetIt.I.get<ReaderViewModel>();

    // 获取屏幕尺寸并设置到 ViewModel
    final screenSize = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    vm.pageWidth.value = screenSize.width - padding.horizontal;
    vm.pageHeight.value = screenSize.height - padding.vertical;

    // 初始化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      vm.initialize(bookId, initialChapterId: initialChapterId);
    });

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          vm.dispose();
        }
      },
      child: Watch.builder(
        builder: (context) {
          final themeMode = vm.themeMode.value;
          final showToolbar = vm.showToolbar.value;
          final showCatalog = vm.showCatalog.value;
          final showSettings = vm.showSettings.value;
          final showBookmarks = vm.showBookmarks.value;

          return Scaffold(
            body: Container(
              color: _getBackgroundColor(themeMode),
              child: SafeArea(
                child: Stack(
                  children: [
                    // 阅读区域
                    GestureDetector(
                      onTap: vm.toggleToolbar,
                      child: ReaderContent(
                        bookId: vm.bookId.value,
                        chapterId: vm.chapterId.value,
                        pageIndex: vm.pageIndex.value,
                        fontSize: vm.fontSize.value,
                        lineHeight: vm.lineHeight.value,
                        themeMode: themeMode,
                        readingMode: vm.readingMode.value,
                        onPageChanged: vm.loadPage,
                        onTotalPagesChanged: (total) =>
                            vm.totalPages.value = total,
                        autoScrollTick: vm.autoScrollTick.value,
                      ),
                    ),
                    // 顶部工具栏
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: AnimatedOpacity(
                        opacity: showToolbar ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: ReaderToolbar(
                          title: vm.currentChapterTitle,
                          progress: vm.progressText,
                          themeMode: themeMode,
                          hasBookmark: vm.hasBookmarkAtCurrentPosition,
                          onClose: () => context.pop(),
                          onToggleToolbar: vm.toggleToolbar,
                          onShowCatalog: vm.toggleCatalog,
                          onShowBookmarks: vm.toggleBookmarks,
                          onToggleBookmark: () =>
                              vm.toggleBookmarkAtCurrentPosition(),
                        ),
                      ),
                    ),
                    // 底部工具栏
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: AnimatedOpacity(
                        opacity: showToolbar ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: ReaderBottomToolbar(
                          currentChapterId: vm.chapterId.value,
                          currentPageIndex: vm.pageIndex.value,
                          totalPages: vm.totalPages.value,
                          themeMode: themeMode,
                          onPreviousChapter: vm.previousChapter,
                          onNextChapter: vm.nextChapter,
                          onPreviousPage: vm.previousPage,
                          onNextPage: vm.nextPage,
                          onShowSettings: vm.toggleSettings,
                        ),
                      ),
                    ),
                    // 章节列表
                    if (showCatalog)
                      ChapterListWidget(
                        chapters: vm.chapters.value.value ?? [],
                        currentChapterId: vm.chapterId.value.toString(),
                        themeMode: themeMode,
                        onChapterSelected: (chapterId) {
                          // 将 String 类型的 chapterId 转换为 int 索引
                          final index = int.tryParse(chapterId) ?? 0;
                          vm.jumpToChapter(index);
                        },
                        onClose: vm.toggleCatalog,
                      ),
                    // 设置面板
                    if (showSettings)
                      ReaderSettingsPanel(
                        themeMode: themeMode,
                        readingMode: vm.readingMode.value,
                        fontSize: vm.fontSize.value,
                        lineHeight: vm.lineHeight.value,
                        onReadingModeChanged: vm.setReadingMode,
                        onFontSizeChanged: vm.setFontSize,
                        onLineHeightChanged: vm.setLineHeight,
                        onThemeChanged: vm.setTheme,
                        onClose: vm.toggleSettings,
                      ),
                    // 书签面板
                    if (showBookmarks)
                      BookmarkWidget(
                        bookmarks: vm.bookmarks.value.value ?? [],
                        themeMode: themeMode,
                        onBookmarkSelected: vm.jumpToBookmark,
                        onAddBookmark: vm.addBookmark,
                        onDeleteBookmark: (bookmarkId) {
                          vm.deleteBookmark(bookmarkId.hashCode);
                        },
                        onClose: vm.toggleBookmarks,
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getBackgroundColor(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.dark:
        return const Color(0xFF1a1a1a);
      case ThemeMode.light:
      default:
        return const Color(0xFFF5F5DC); // 米黄色护眼背景
    }
  }
}
