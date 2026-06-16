import 'dart:async';

import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/app_error_mapper.dart';
import 'package:flutter/services.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/features/reader/annotations/application/annotation_view_model.dart';
import 'package:zephyr_reader/features/reader/annotations/application/bookmark_view_model.dart';
import 'package:zephyr_reader/features/reader/core/domain/reader_repository_interface.dart';
import 'package:zephyr_reader/features/reader/translation/application/translation_config.dart';
import 'package:zephyr_reader/features/reader/translation/application/translation_view_model.dart';
import 'package:zephyr_reader/features/reader/translation/domain/translation_service.dart';
import 'chapter_view_model.dart';
import 'reader_page_state.dart';
import 'reading_session_manager.dart';
import 'package:zephyr_reader/di/service_locator.dart';

/// 阅读器视图模型 — Facade
///
/// 轻量协调层：持有各子 ViewModel，代理信号访问，处理跨 ViewModel 的编排逻辑。
/// 书籍/章节状态和分页 → ChapterViewModel。
/// 阅读计时和进度保存 → ReadingSessionManager。
/// 书签 → BookmarkViewModel。
/// 划词批注 → AnnotationViewModel。
/// 翻译/双语 → TranslationViewModel。
class ReaderViewModel {
  final ReaderRepositoryInterface _repo;
  final ReaderConfig _config;

  /// 阅读配置
  ReaderConfig get config => _config;

  // ==================== 子 ViewModel ====================

  late final ChapterViewModel chapterManager;
  late final ReadingSessionManager sessionManager;
  late final BookmarkViewModel bookmarks;
  late final AnnotationViewModel annotations;
  late final TranslationViewModel translation;

  // ==================== 跨切面信号 ====================

  final toastMessage = signal<String>('');

  // ==================== 定时器 ====================

  Timer? _reloadDebounce;

  final List<void Function()> _disposers = [];

  final ReaderPageState state = ReaderPageState();

  ReaderViewModel({
    required ReaderRepositoryInterface repo,
    ReaderConfig? config,
    TranslationConfig? translationConfig,
    TranslationService? translationService,
  })
    : _repo = repo,
      _config = config ?? getIt<ReaderConfig>() {
    chapterManager = ChapterViewModel(_repo, _config, state);
    sessionManager = ReadingSessionManager(state, chapterManager);
    bookmarks = BookmarkViewModel(state);
    annotations = AnnotationViewModel(state);
    translation = TranslationViewModel(
      state,
      config: translationConfig,
      service: translationService,
    );
  }

  /// 公开仓库访问（渲染层使用）。
  ReaderRepositoryInterface get repo => _repo;

  // ==================== 编排方法 ====================

  /// 初始化阅读器，加载章节列表、恢复阅读进度、加载书签并开始计时。
  Future<void> initialize(String bookId, {int initialChapterId = 0}) async {
    await resetForNewBook();
    state.bookId.value = bookId;
    state.currentCharOffset.value = 0;

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

    try {
      await chapterManager.loadChapters();
      await chapterManager.loadLastProgress();

      final chaptersList = chapterManager.chapters.value.value;
      if (chaptersList != null && chaptersList.isNotEmpty) {
        final restoredChapterIndex = state.chapterIndex.value;
        final restoredCharOffset = state.currentCharOffset.value;
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
          restartSession: false,
          onChapterLoaded: annotations.loadHighlights,
        );
      }

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
    bool restartSession = true,
  }) async {
    await chapterManager.loadChapter(
      chapterIndex,
      initialCharOffset: initialCharOffset,
      restartSession: restartSession,
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
    } catch (_) {
      toastMessage.value = l10n.saveHighlightFailed;
    }
  }

  Future<void> saveAnnotation(
    String annotationContent,
    AppLocalizations l10n,
  ) async {
    try {
      await annotations.saveAnnotation(annotationContent);
    } catch (_) {
      toastMessage.value = l10n.saveAnnotationFailed;
    }
  }

  Future<void> deleteNote(String noteId, AppLocalizations l10n) async {
    try {
      await translation.deleteBilingualPair(noteId: noteId);
      await HapticFeedback.heavyImpact();
      await annotations.loadHighlights(forceRefresh: true);
    } catch (_) {
      toastMessage.value = l10n.deleteHighlightFailed;
    }
  }

  Future<void> updateNote(Note note, AppLocalizations l10n) async {
    try {
      await annotations.updateNote(note);
    } catch (_) {
      toastMessage.value = l10n.updateNoteFailed;
    }
  }

  // ==================== 设置变更 ====================

  void _debounceReloadChapter() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(
        chapterManager.loadChapter(
          state.chapterIndex.value,
          initialCharOffset: state.currentCharOffset.value,
          restartSession: true,
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
    state.readingMode.value = mode;
    if (mode == ReadingMode.bilingual) {
      translation.onEnterBilingualMode();
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
    await translation.reset();

    toastMessage.value = '';
    state.reset();
  }
}
