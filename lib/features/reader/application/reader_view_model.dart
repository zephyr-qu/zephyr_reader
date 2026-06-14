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
/// 轻量协调层：持有各子 ViewModel，处理跨 ViewModel 的编排逻辑。
/// 页面/测试通过公开字段直接访问子 VM。
///
/// 编排逻辑（保留在此）：
/// - 初始化/重置各子 VM 的启动停止
/// - 跨子 VM 的操作（deleteNote, setReadingMode）
/// - 配置变更后的 debounced 重载
/// - 带 toast 错误处理的便利方法
@lazySingleton
class ReaderViewModel {
  final ReaderRepository _repo;
  final ReaderConfig _config;

  /// 阅读配置
  ReaderConfig get config => _config;

  // ==================== 子 ViewModel ====================

  late final ChapterViewModel chapterManager;
  late final ReadingSessionManager sessionManager;
  late final BookmarkViewModel bookmarks;
  late final AnnotationViewModel annotations;
  late final TranslationViewModel translation;

  /// 字体大小（double，供 bindings 消费）
  late final ReadonlySignal<double> fontSizeDouble = computed(
    () => _config.fontSize.value,
  );

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

    bookmarks = BookmarkViewModel(
      chapterManager.bookId,
      chapterManager.chapterIndex,
      chapterManager.currentCharOffset,
    );
    annotations = AnnotationViewModel(
      chapterManager.bookId,
      chapterManager.chapterIndex,
    );
    translation = TranslationViewModel(
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

  // ==================== 加载/导航（代理章节管理器，带编排） ====================

  /// 加载指定章节（章节切换时自动加载高亮）。
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

  /// 翻页（自动保存进度）。
  Future<void> loadPage(int pageIndex) async {
    chapterManager.loadPage(pageIndex);
    unawaited(sessionManager.saveProgress());
  }

  // ==================== 划词批注（带 toast 错误处理） ====================

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

  /// 删除笔记：同时清理双语高亮对，刷新高亮列表。
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
          chapterManager.chapterIndex.value,
          initialCharOffset: chapterManager.currentCharOffset.value,
          restartSession: false,
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
    chapterManager.readingMode.value = mode;
    if (mode == ReadingMode.bilingual) {
      translation.onEnterBilingualMode();
    }
  }

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
      await translation.createBilingualHighlight(
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

    bookmarks.reset();
    annotations.reset();
    await translation.reset();

    toastMessage.value = '';
  }
}
