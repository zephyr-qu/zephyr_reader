import 'package:zephyr_reader/src/rust/domain/bookmark/models.dart';
import 'package:zephyr_reader/src/rust/domain/note/models.dart';

import 'dart:async';

import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/app_error_mapper.dart';
import 'package:flutter/services.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

import 'package:zephyr_reader/features/reader/annotations/application/bookmark_view_model.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/features/reader/annotations/application/annotation_view_model.dart';
import 'package:zephyr_reader/features/reader/core/data/reader_render_data_source.dart';
import 'package:zephyr_reader/features/reader/domain/bilingual_reader_delegate.dart';
import 'package:zephyr_reader/features/reader/domain/chapter_content_repository.dart';
import 'package:zephyr_reader/features/reader/domain/progress_repository.dart';
import 'package:zephyr_reader/reader_engine/pagination/flutter_pagination_session.dart';
import 'chapter_view_model.dart';
import 'reading_session_manager.dart';
import 'package:zephyr_reader/di/service_locator.dart';

/// 阅读器视图模型 — Facade
///
/// 轻量协调层：持有各子 ViewModel，代理信号访问，处理跨 ViewModel 的编排逻辑。
/// 书籍/章节状态和分页 → ChapterViewModel。
/// 阅读计时和进度保存 → ReadingSessionManager。
/// 书签 → BookmarkViewModel。
/// 划词批注 → AnnotationViewModel。
/// 双语 → BilingualReaderDelegate（可选，core 不依赖实现）。
class ReaderViewModel {
  final ChapterContentRepository _contentRepo;
  final PaginationSession _session;
  final ProgressRepository _progressRepo;
  final ReaderRenderDataSource dataSource;
  final ReaderConfig _config;

  /// 阅读配置
  ReaderConfig get config => _config;

  // ==================== 子 ViewModel ====================

  late final ChapterViewModel chapterManager;
  late final ReadingSessionManager sessionManager;
  late final BookmarkViewModel bookmarks;
  late final AnnotationViewModel annotations;
  BilingualReaderDelegate? bilingual;

  // ==================== 跨切面信号 ====================

  final toastMessage = signal<String>('');
  final readingMode = signal<ReadingMode>(ReadingMode.pagination);

  // ==================== 定时器 ====================

  Timer? _reloadDebounce;

  final List<void Function()> _disposers = [];

  ReaderViewModel({
    required this._contentRepo,
    required this._session,
    required this._progressRepo,
    required this.dataSource,
    ReaderConfig? config,
    this.bilingual,
  }) : _config = config ?? getIt<ReaderConfig>() {
    chapterManager = ChapterViewModel(
      _contentRepo,
      _session,
      _progressRepo,
      _config,
    );
    sessionManager = getIt<ReadingSessionManager>(param1: chapterManager);
    bookmarks = getIt<BookmarkViewModel>(param1: chapterManager);
    annotations = getIt<AnnotationViewModel>(param1: chapterManager);
  }

  // ==================== 编排方法 ====================

  /// 初始化阅读器，加载章节列表、恢复阅读进度、加载书签并开始计时。
  Future<void> initialize(String bookId, {int initialChapterId = 0}) async {
    await resetForNewBook();
    chapterManager.bookId.value = bookId;
    chapterManager.currentCharOffset.value = 0;

    chapterManager.isLoading.value = true;
    chapterManager.error.value = null;

    _disposers.add(
      effect(() {
        if (_config.autoScroll.value && sessionManager.isReading.value) {
          chapterManager.startAutoScroll();
        } else {
          chapterManager.stopAutoScroll();
        }
      }),
    );
    _disposers.add(
      effect(() {
        final err = annotations.highlightsError.value;
        if (err != null) {
          toastMessage.value = err;
          annotations.highlightsError.value = null; // 消费后重置，避免重复提示
        }
      }),
    );

    try {
      await chapterManager.loadChapters();
      await chapterManager.loadLastProgress();

      final chaptersList = chapterManager.chapters.value.value;
      if (chaptersList != null && chaptersList.isNotEmpty) {
        final restoredChapterIndex = chapterManager.chapterIndex.value;
        final restoredCharOffset = chapterManager.currentCharOffset.value;
        final targetChapterIndex = initialChapterId > 0
            ? initialChapterId
            : restoredChapterIndex;
        final targetCharOffset =
            initialChapterId > 0 && initialChapterId != restoredChapterIndex
            ? 0
            : restoredCharOffset;
        await chapterManager.loadChapter(
          targetChapterIndex,
          initialCharOffset: targetCharOffset,
          readingMode: readingMode.value,
          onChapterLoaded: annotations.loadHighlights,
        );
      }

      chapterManager.activeReadingMode = readingMode.value;

      await bookmarks.loadBookmarks();
      sessionManager.startReading();
      sessionManager.startAutoSave();
    } catch (e) {
      chapterManager.error.value = AppErrorMapper.humanReadable(e);
      Logging.error('ReaderViewModel.initialize error', exception: e);
    } finally {
      chapterManager.isLoading.value = false;
    }
  }

  // ==================== 章节导航 ====================

  Future<void> loadChapter(
    int chapterIndex, {
    int initialCharOffset = 0,
  }) async {
    await chapterManager.loadChapter(
      chapterIndex,
      initialCharOffset: initialCharOffset,
      readingMode: readingMode.value,
      onChapterLoaded: annotations.loadHighlights,
    );
  }

  Future<void> loadPage(int pageIndex) async {
    chapterManager.loadPage(pageIndex);
    unawaited(sessionManager.saveProgress());
  }

  // ==================== 书签 ====================

  Future<void> jumpToBookmark(Bookmark bookmark) async {
    await chapterManager.jumpToPosition(
      bookmark.chapterIndex,
      bookmark.charOffset.toInt(),
    );
  }

  Bookmark? get currentBookmark => bookmarks.currentBookmark;

  Future<bool> toggleBookmarkAtCurrentPosition() async {
    final existing = bookmarks.currentBookmark;
    if (existing != null) {
      return await bookmarks.deleteBookmark(existing.id);
    } else {
      return await bookmarks.addBookmark(
        chapterTitle: chapterManager.currentChapterTitle.value,
      );
    }
  }

  // ==================== 划词批注 ====================

  Future<void> saveHighlight(AppLocalizations l10n) async {
    try {
      await annotations.saveHighlight();
    } catch (e) {
      Logging.error('保存高亮失败', exception: e);
      toastMessage.value = l10n.saveHighlightFailed;
    }
  }

  Future<void> saveAnnotation(
    String annotationContent,
    AppLocalizations l10n,
  ) async {
    try {
      await annotations.saveAnnotation(annotationContent);
    } catch (e) {
      Logging.error('保存批注失败', exception: e);
      toastMessage.value = l10n.saveAnnotationFailed;
    }
  }

  Future<void> deleteNote(String noteId, AppLocalizations l10n) async {
    try {
      await bilingual?.deleteBilingualPair(noteId: noteId);
      await HapticFeedback.heavyImpact();
      await annotations.loadHighlights(forceRefresh: true);
    } catch (e) {
      Logging.error('删除笔记失败(noteId=$noteId)', exception: e);
      toastMessage.value = l10n.deleteHighlightFailed;
    }
  }

  Future<void> updateNote(Note note, AppLocalizations l10n) async {
    try {
      await annotations.updateNote(note);
    } catch (e) {
      Logging.error('更新笔记失败', exception: e);
      toastMessage.value = l10n.updateNoteFailed;
    }
  }

  // ==================== 设置变更 ====================

  void _debounceReloadChapter() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(
        chapterManager.loadChapter(
          chapterManager.chapterIndex.value,
          initialCharOffset: chapterManager.currentCharOffset.value,
          readingMode: readingMode.value,
          preserveContent: true,
          onChapterLoaded: annotations.loadHighlights,
        ),
      );
    });
  }

  void setFontSize(double size) {
    _config.fontSize.value = size;
    _debounceReloadChapter();
  }

  void setLineHeight(double height) {
    _config.lineHeight.value = height;
    _debounceReloadChapter();
  }

  void setLetterSpacing(double value) {
    _config.letterSpacing.value = value;
    _debounceReloadChapter();
  }

  void setParagraphSpacing(double value) {
    _config.paragraphSpacing.value = value;
    _debounceReloadChapter();
  }

  void setPageMargin(double value) {
    _config.padding.value = value;
    _debounceReloadChapter();
  }

  void setReadingMode(ReadingMode mode) {
    readingMode.value = mode;
    chapterManager.activeReadingMode = mode;
    if (mode == ReadingMode.bilingual) {
      bilingual?.onEnterBilingualMode();
    }
    // 切换到 scroll/bilingual 前，释放分页会话，
    // 避免 PaginationSession 和 LRU engine 悬空占用内存。
    if (mode != ReadingMode.pagination) {
      _session.dispose();
    }
    if (mode == ReadingMode.scroll) {
      final content = chapterManager.chapterContent.value.value;
      if (content != null && content.isNotEmpty) {
        chapterManager.resetScrollDocument(
          content,
          chapterManager.chapterIndex.value,
          chapterIr: _contentRepo.currentChapterIr,
          chapterFilePath: _contentRepo.currentChapterFilePath,
        );
      }
    }
  }

  // ==================== 重置 ====================

  Future<void> resetForNewBook() async {
    _reloadDebounce?.cancel();
    for (final disposer in _disposers) {
      disposer();
    }
    _disposers.clear();

    await sessionManager.stopReading();
    chapterManager.reset();

    bookmarks.reset();
    annotations.reset();
    await bilingual?.reset();
    toastMessage.value = '';

    readingMode.value = ReadingMode.pagination;
  }
}
