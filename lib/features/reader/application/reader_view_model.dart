import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/app_error_mapper.dart';
import 'package:flutter/services.dart';
import 'package:zephyr_reader/src/rust/api/bilingual.dart';
import 'package:zephyr_reader/features/reader/application/translation_config.dart';
import 'package:zephyr_reader/features/reader/domain/translation_service.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

import '../../../core/reader/reader_config.dart';
import '../data/repositories/rust_reader_repository.dart';
import 'chapter_view_model.dart';
import 'reading_session_manager.dart';
import 'bookmark_view_model.dart';
import 'annotation_view_model.dart';
import 'translation_view_model.dart';

/// 阅读器视图模型 — Facade
///
/// 轻量协调层：持有各子 ViewModel，代理信号访问，处理跨 ViewModel 的编排逻辑。
/// 书籍/章节状态和分页 → ChapterViewModel。
/// 阅读计时和进度保存 → ReadingSessionManager。
/// 书签 → BookmarkViewModel。
/// 划词批注 → AnnotationViewModel。
/// 翻译/双语 → TranslationViewModel。
@lazySingleton
class ReaderViewModel {
  final ReaderRepository _repo;
  final ReaderConfig _config;

  /// 阅读配置
  ReaderConfig get config => _config;

  // ==================== 子 ViewModel ====================

  late final ChapterViewModel chapterManager;
  late final ReadingSessionManager sessionManager;
  late final BookmarkViewModel _bookmarks;
  late final AnnotationViewModel _annotations;
  late final TranslationViewModel _translation;

  // ==================== 快捷 getter（ChapterViewModel） ====================

  Signal<String> get bookId => chapterManager.bookId;
  Signal<int> get chapterIndex => chapterManager.chapterIndex;
  AsyncSignal<List<Chapter>> get chapters => chapterManager.chapters;
  AsyncSignal<String> get chapterContent => chapterManager.chapterContent;
  Signal<int> get totalPages => chapterManager.totalPages;
  Signal<int> get pageIndex => chapterManager.pageIndex;
  Signal<int> get currentCharOffset => chapterManager.currentCharOffset;
  Signal<int?> get pendingJumpCharOffset =>
      chapterManager.pendingJumpCharOffset;
  Signal<bool> get isLoading => chapterManager.isLoading;
  Signal<String?> get error => chapterManager.error;
  double get pageWidth => chapterManager.pageWidth;
  double get pageHeight => chapterManager.pageHeight;
  double get devicePixelRatio => chapterManager.devicePixelRatio;
  set pageWidth(double value) => chapterManager.pageWidth = value;
  set pageHeight(double value) => chapterManager.pageHeight = value;
  set devicePixelRatio(double value) => chapterManager.devicePixelRatio = value;
  Signal<ReadingMode> get readingMode => chapterManager.readingMode;
  Signal<int> get autoScrollTick => chapterManager.autoScrollTick;
  ReadonlySignal<String> get progressText => chapterManager.progressText;
  ReadonlySignal<String> get currentChapterTitle =>
      chapterManager.currentChapterTitle;

  /// 字体大小（double，供 bindings 消费）
  late final ReadonlySignal<double> fontSizeDouble = computed(
    () => _config.fontSize.value,
  );

  // ==================== 书签 getter ====================

  AsyncSignal<List<Bookmark>> get bookmarks => _bookmarks.bookmarks;

  // ==================== 批注 getter ====================

  Signal<String> get selectedText => _annotations.selectedText;
  Signal<int> get selectionStart => _annotations.selectionStart;
  Signal<int> get selectionEnd => _annotations.selectionEnd;
  AsyncSignal<List<Note>> get highlights => _annotations.highlights;

  // ==================== 翻译/双语 getter ====================

  bool get isTranslationConfigured => _translation.isConfigured;
  AsyncSignal<BilingualAlignment?> get bilingualAlignment =>
      _translation.bilingualAlignment;
  Signal<String> get translationContent => _translation.translationContent;

  // ==================== 跨切面信号 ====================

  final toastMessage = signal<String>('');

  // ==================== 定时器 ====================

  Timer? _reloadDebounce;
  final List<void Function()> _disposers = [];

  ReaderViewModel(
    this._repo,
    this._config,
    TranslationConfig translateConfig,
    TranslationService translateService,
  ) {
    chapterManager = ChapterViewModel(_repo, _config);
    sessionManager = ReadingSessionManager(chapterManager);

    _bookmarks = BookmarkViewModel(
      chapterManager.bookId,
      chapterManager.chapterIndex,
      chapterManager.currentCharOffset,
    );
    _annotations = AnnotationViewModel(
      chapterManager.bookId,
      chapterManager.chapterIndex,
    );
    _translation = TranslationViewModel(
      chapterManager.bookId,
      chapterManager.chapterIndex,
      chapterManager.chapterContent,
      chapterManager.readingMode,
      translateConfig,
      translateService,
    );
  }

  // ==================== 编排方法 ====================

  /// 初始化阅读器，加载章节列表、恢复阅读进度、加载书签并开始计时。
  Future<void> initialize(String bookId, {int initialChapterId = 0}) async {
    await resetForNewBook();
    chapterManager.bookId.value = bookId;
    chapterManager.currentCharOffset.value = 0;

    isLoading.value = true;
    error.value = null;

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

      final chaptersList = chapters.value.value;
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
          restartSession: false,
          onChapterLoaded: _annotations.loadHighlights,
        );
      }

      await _bookmarks.loadBookmarks();
      sessionManager.startReading();
      sessionManager.startAutoSave();
    } catch (e) {
      error.value = AppErrorMapper.humanReadable(e);
      Logging.error('ReaderViewModel.initialize error', exception: e);
    } finally {
      isLoading.value = false;
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
      onChapterLoaded: _annotations.loadHighlights,
    );
  }

  Future<void> loadPage(int pageIndex) async {
    chapterManager.loadPage(pageIndex);
    unawaited(sessionManager.saveProgress());
  }

  Future<void> jumpToChapter(int chapterIndex) async {
    await chapterManager.jumpToChapter(chapterIndex);
  }

  Future<void> jumpToPosition(int chapterIndex, int charOffset) async {
    await chapterManager.jumpToPosition(chapterIndex, charOffset);
  }

  Future<void> previousChapter() => chapterManager.previousChapter();
  Future<void> nextChapter() => chapterManager.nextChapter();
  Future<void> previousPage() => chapterManager.previousPage();
  Future<void> nextPage() => chapterManager.nextPage();

  void updateCurrentCharOffset(int charOffset) =>
      chapterManager.updateCurrentCharOffset(charOffset);

  void consumePendingJumpOffset() => chapterManager.consumePendingJumpOffset();

  void updateFont(String fontFamily) => chapterManager.updateFont(fontFamily);

  // ==================== 书签（代理到 BookmarkController） ====================

  Future<void> loadBookmarks() => _bookmarks.loadBookmarks();
  Future<bool> addBookmark() => _bookmarks.addBookmark();
  Future<bool> deleteBookmark(String bookmarkId) =>
      _bookmarks.deleteBookmark(bookmarkId);

  Future<void> jumpToBookmark(Bookmark bookmark) async {
    await jumpToPosition(bookmark.chapterIndex, bookmark.charOffset.toInt());
  }

  bool get hasBookmarkAtCurrentPosition =>
      _bookmarks.hasBookmarkAtCurrentPosition;
  Bookmark? get currentBookmark => _bookmarks.currentBookmark;

  Future<bool> toggleBookmarkAtCurrentPosition() async {
    final existing = currentBookmark;
    if (existing != null) {
      return await _bookmarks.deleteBookmark(existing.id);
    } else {
      return await _bookmarks.addBookmark();
    }
  }

  // ==================== 划词批注（代理到 AnnotationController） ====================

  Future<void> loadHighlights({bool forceRefresh = false}) =>
      _annotations.loadHighlights(forceRefresh: forceRefresh);

  void updateSelection(String text, int start, int end) =>
      _annotations.updateSelection(text, start, end);

  void clearSelection() => _annotations.clearSelection();

  Future<void> saveHighlight(AppLocalizations l10n) async {
    try {
      await _annotations.saveHighlight();
    } catch (_) {
      toastMessage.value = l10n.saveHighlightFailed;
    }
  }

  Future<void> saveAnnotation(
    String annotationContent,
    AppLocalizations l10n,
  ) async {
    try {
      await _annotations.saveAnnotation(annotationContent);
    } catch (_) {
      toastMessage.value = l10n.saveAnnotationFailed;
    }
  }

  Future<void> deleteNote(String noteId, AppLocalizations l10n) async {
    try {
      await _translation.deleteBilingualPair(noteId: noteId);
      await HapticFeedback.heavyImpact();
      await _annotations.loadHighlights(forceRefresh: true);
    } catch (_) {
      toastMessage.value = l10n.deleteHighlightFailed;
    }
  }

  Future<void> updateNote(Note note, AppLocalizations l10n) async {
    try {
      await _annotations.updateNote(note);
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
          chapterIndex.value,
          initialCharOffset: currentCharOffset.value,
          restartSession: false,
          onChapterLoaded: _annotations.loadHighlights,
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
    if (mode == ReadingMode.bilingual) {
      _translation.onEnterBilingualMode();
    }
  }

  void setTranslationContent(String content) =>
      _translation.setTranslationContent(content);

  Future<void> translateChapter() => _translation.translateChapter();

  // ==================== 双语高亮 ====================

  Future<void> createBilingualHighlight({
    required AppLocalizations l10n,
    required String sourceBookId,
    required int sourceChapterIndex,
    required int sourceCharOffset,
    required int sourceLength,
    required String sourceSelectedText,
    required String sourceLanguage,
    required String targetBookId,
    required int targetChapterIndex,
    required int targetCharOffset,
    required int targetLength,
    required String targetSelectedText,
    required String targetLanguage,
    int highlightColor = 0xFFE91E63,
  }) async {
    try {
      await _translation.createBilingualHighlight(
        BilingualHighlightParams(
          sourceBookId: sourceBookId,
          sourceChapterIndex: sourceChapterIndex,
          sourceCharOffset: sourceCharOffset,
          sourceLength: sourceLength,
          sourceSelectedText: sourceSelectedText,
          sourceLanguage: sourceLanguage,
          targetBookId: targetBookId,
          targetChapterIndex: targetChapterIndex,
          targetCharOffset: targetCharOffset,
          targetLength: targetLength,
          targetSelectedText: targetSelectedText,
          targetLanguage: targetLanguage,
          highlightColor: highlightColor,
        ),
      );
    } catch (e, stack) {
      Logging.error(
        'ReaderViewModel.createBilingualHighlight',
        exception: e,
        stackTrace: stack,
      );
      toastMessage.value = l10n.bilingualHighlightFailed;
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

    _bookmarks.reset();
    _annotations.reset();
    await _translation.reset();

    toastMessage.value = '';
  }
}
