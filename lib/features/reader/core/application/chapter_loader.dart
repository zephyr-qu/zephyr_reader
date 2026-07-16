import 'package:zephyr_reader/src/rust/domain/chapter/models.dart';

import 'dart:async';

import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_load_orchestrator.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_load_phase.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_load_request.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_view_model.dart';
import 'package:zephyr_reader/features/reader/core/application/pagination_coordinator.dart';
import 'package:zephyr_reader/features/reader/domain/chapter_content_repository.dart';
import 'package:zephyr_reader/features/reader/domain/progress_repository.dart';
import 'package:zephyr_reader/reader_engine/pagination/flutter_pagination_session.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 章节内容加载编排。
///
/// 负责章节列表、阅读进度、章节内容加载及预取。
class ChapterLoader {
  final ChapterContentRepository _contentRepo;
  final ProgressRepository _progressRepo;
  final PaginationSession _session;
  final ChapterViewModel _chapterVM;
  final PaginationCoordinator _pagination;
  late final ChapterLoadOrchestrator _orchestrator;

  /// 章节索引调度（构造后由 [ChapterViewModel] 注入）。
  Future<void> Function(int chapterIndex, String content)? scheduleSearchIndex;

  /// 章节列表
  final AsyncSignal<List<Chapter>> chapters = asyncSignal<List<Chapter>>(
    AsyncState.data([]),
  );

  /// 总页数（分页模式）
  final totalPages = signal<int>(0);

  /// 当前页码
  final pageIndex = signal<int>(0);

  /// 是否正在加载
  final isLoading = signal<bool>(false);

  /// 错误信息
  final error = signal<String?>(null);

  /// 章节加载状态机当前阶段
  final loadPhase = signal<ChapterLoadPhase>(ChapterLoadPhase.idle);

  /// 首屏就绪后预加载相邻章节首页（由 [ChapterNavigator] 注入）。
  Future<void> Function(int chapterIndex)? preloadAdjacentFirstPages;

  ChapterLoader(
    this._contentRepo,
    this._progressRepo,
    this._session,
    this._chapterVM,
    this._pagination,
  ) {
    _orchestrator = ChapterLoadOrchestrator(
      contentRepo: _contentRepo,
      session: _session,
      chapterVM: _chapterVM,
      pagination: _pagination,
      chapters: chapters,
      totalPages: totalPages,
      pageIndex: pageIndex,
      isLoading: isLoading,
      error: error,
      loadPhase: loadPhase,
    );
  }

  /// 设置字体信息
  void updateFont(String fontFamily) {
    _pagination.fontFamily = fontFamily;
  }

  /// 加载章节列表
  Future<void> loadChapters() async {
    chapters.value = AsyncState.loading();
    try {
      final data = await _contentRepo.getChapters(_chapterVM.bookId.value);
      chapters.value = AsyncState.data(data);
    } catch (e) {
      Logging.error(
        'Failed to load chapter list (book=${_chapterVM.bookId.value})',
        exception: e,
      );
      chapters.value = AsyncState.error(e);
      rethrow;
    }
  }

  /// 加载上次的阅读进度
  Future<void> loadLastProgress() async {
    try {
      final progress = await _progressRepo.load(_chapterVM.bookId.value);
      if (progress != null) {
        _chapterVM.chapterIndex.value = progress.chapterIndex;
        _chapterVM.currentCharOffset.value = progress.charOffset;
      }
    } catch (e) {
      Logging.error('Failed to load reading progress', exception: e);
    }
  }

  Future<void> loadChapter(
    int chapterIndex, {
    int initialCharOffset = 0,
    ReadingMode readingMode = ReadingMode.pagination,
    Future<void> Function()? onChapterLoaded,
    bool? preserveContent,
    ChapterNavigationKind navigationKind = ChapterNavigationKind.manualJump,
  }) {
    _pagination.syncChapterTypesetLayoutToRepo();
    return _orchestrator.run(
      ChapterLoadRequest(
        chapterIndex: chapterIndex,
        initialCharOffset: initialCharOffset,
        readingMode: readingMode,
        preserveContent: preserveContent,
        onChapterLoaded: onChapterLoaded,
        navigationKind: navigationKind,
      ),
      scheduleSearchIndex: scheduleSearchIndex,
      preloadAdjacentFirstPages: preloadAdjacentFirstPages,
    );
  }

  void resetSignals() {
    _orchestrator.resetPhase();
    chapters.value = AsyncState.data([]);
    totalPages.value = 0;
    pageIndex.value = 0;
    isLoading.value = false;
    error.value = null;
  }
}
