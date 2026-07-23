import 'package:flutter/foundation.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../reading_backend.dart';
import '../reading_backend_kind.dart';
import '../reading_capabilities.dart';
import '../reading_command.dart';
import '../reading_open_request.dart';
import '../reading_snapshot.dart';
import '../reading_status.dart';
import '../../preferences/reading_preferences.dart';
import '../../position/reading_position.dart';
import '../../chapter/reading_chapter.dart';
import 'package:zephyr_reader/features/reader/core/application/reader_view_model.dart';
import 'package:zephyr_reader/core/reader_engine/shared/config/reader_config.dart' show ReadingMode;
///
/// Maps the engine-neutral [ReadingBackend] seam to the existing
/// ReaderViewModel + ChapterViewModel + PaginationEngine + ReaderConfig.
///
/// ## Design principles
/// - Does not rewrite PaginationEngine or any existing reading logic.
/// - Is the formal entry point for the builtin engine.
/// - After page migration, callers must stop consuming ReaderViewModel
///   directly and go through this backend instead.
class BuiltinReadingBackend implements ReadingBackend {
  @override
  final ReadingBackendKind kind = ReadingBackendKind.builtin;

  @override
  final ReadingCapabilities capabilities = ReadingCapabilities.builtin;

  @override
  final ValueNotifier<ReadingSnapshot> snapshot;

  final ReaderViewModel _vm;
  /// Temporary accessor for migration period (R9-R12).
  /// After full migration, all callers should use the ReadingBackend
  /// interface instead.
  ReaderViewModel get viewModel => _vm;

  /// Called after chapters are loaded from the database.
  void Function(List<ReadingChapter> chapters)? onChaptersReady;

  BuiltinReadingBackend({
    required ReaderViewModel viewModel,
  }) : _vm = viewModel,
       snapshot = ValueNotifier<ReadingSnapshot>(ReadingSnapshot.closed) {
    _setupSnapshotListener();
  }

  // ---------------------------------------------------------------
  // Snapshot composition — watches VM signals and produces unified state
  // ---------------------------------------------------------------

  /// Set up reactive listener that combines VM signals into a single snapshot.
  void _setupSnapshotListener() {
    // Initial snapshot: opening
    _updateSnapshot(ReadingStatus.opening);

    // Watch loading state
    effect(() {
      final isLoading = _vm.chapterManager.isLoading.value;
      final error = _vm.chapterManager.error.value;
      if (error != null) {
        _updateSnapshot(ReadingStatus.failed, errorMessage: error);
      } else if (!isLoading && snapshot.value.status == ReadingStatus.opening) {
        _updateSnapshot(ReadingStatus.ready);
      }
    });

    // Watch position
    effect(() {
      final chapterIdx = _vm.chapterManager.chapterIndex.value;
      final charOffset = _vm.chapterManager.currentCharOffset.value;
      final title = _vm.chapterManager.currentChapterTitle.value;
      _updateSnapshot(
        snapshot.value.status,
        position: ReadingPosition(
          chapterIndex: chapterIdx,
          charOffsetUtf16: charOffset,
        ),
        chapterTitle: title,
        totalProgress: _computeProgress(),
      );
    });

    // Watch chapters for TOC
    effect(() {
      final rustChapters = _vm.chapterManager.chapters.value.value;
      if (rustChapters == null || rustChapters.isEmpty) return;
      final readingChapters = rustChapters
          .map((ch) => ReadingChapter(
                id: ch.id,
                index: ch.chapterIndex.toInt(),
                title: ch.title,
              ))
          .toList();
      onChaptersReady?.call(readingChapters);
    });
  }

  void _updateSnapshot(
    ReadingStatus status, {
    ReadingPosition? position,
    String chapterTitle = '',
    double totalProgress = 0.0,
    String? errorMessage,
  }) {
    snapshot.value = ReadingSnapshot(
      status: status,
      bookTitle: _vm.chapterManager.bookId.value,
      chapterTitle: chapterTitle,
      totalProgress: totalProgress,
      position: position,
      errorMessage: errorMessage,
    );
  }

  double _computeProgress() {
    final chapters = _vm.chapterManager.chapters.value.value;
    if (chapters == null || chapters.isEmpty) return 0.0;
    final current = _vm.chapterManager.chapterIndex.value;
    return (current + 1) / chapters.length;
  }

  // ---------------------------------------------------------------
  // ReadingBackend interface
  // ---------------------------------------------------------------

  @override
  Future<void> open(ReadingOpenRequest request) async {
    _updateSnapshot(ReadingStatus.opening);
    await _vm.initialize(request.bookId);
  }

  @override
  Future<void> execute(ReadingCommand command) async {
    switch (command) {
      case PreviousPage():
        await _vm.chapterManager.previousPage();
      case NextPage():
        await _vm.chapterManager.nextPage();
      case PreviousChapter():
        await _vm.chapterManager.previousChapter();
      case NextChapter():
        await _vm.chapterManager.nextChapter();
      case GoToChapter(:final chapterId):
        final idx = int.tryParse(chapterId);
        if (idx != null) {
          await _vm.chapterManager.jumpToChapter(idx);
        }
      case GoToPosition(:final position):
        await _vm.chapterManager.jumpToPosition(
          position.chapterIndex,
          position.charOffsetUtf16,
        );
    }
  }

  @override
  Future<void> applyPreferences(ReadingPreferences preferences) async {
    _vm.setFontSize(preferences.fontSize);
    _vm.setLineHeight(preferences.lineHeight);
    if (preferences.fontFamily != null) {
      _vm.chapterManager.updateFont(preferences.fontFamily!);
    }
    _vm.setPageMargin(preferences.pageMargin);
    // Map scroll/paginated
    final mode = preferences.readingMode == 'scroll'
        ? ReadingMode.scroll
        : ReadingMode.pagination;
    _vm.setReadingMode(mode);
  }

  @override
  Future<void> close() async {
    await _vm.resetForNewBook();
    _updateSnapshot(ReadingStatus.closed);
  }
}

