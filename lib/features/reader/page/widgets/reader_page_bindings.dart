import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/features/reader/application/reader_enums.dart';
import 'package:zephyr_reader/features/reader/application/reader_view_model.dart';
import 'package:zephyr_reader/src/rust/api/bilingual.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class ReaderPageBindings {
  final ReaderTheme readerTheme;
  final bool showToolbar;
  final bool showSettings;
  final bool showCatalog;
  final bool showBookmarks;
  final bool showSelection;
  final bool showSearch;
  final int bgIndex;
  final double brightness;
  final String currentBookId;
  final int chapterIndex;
  final int pageIndex;
  final int totalPages;
  final ReadingMode currentReadingMode;
  final double fontSize;
  final double lineHeight;
  final String content;
  final bool isLoading;
  final String? error;
  final BilingualAlignment? bilingualAlign;
  final bool isBilingualLoading;
  final String? bilingualError;
  final int autoScrollTick;
  final List<Note> highlights;
  final String searchQuery;
  final int searchCurrentIndex;
  final bool searchMatchHighlight;
  final double letterSpacing;
  final double paragraphSpacing;
  final double pageMargin;
  final WritingDirection writingDirection;
  final int? pendingJumpCharOffset;
  final ThemeMode themeMode;
  final int effectiveTotalPages;
  final String progressText;
  final String currentChapterTitle;

  const ReaderPageBindings({
    required this.readerTheme,
    required this.showToolbar,
    required this.showSettings,
    required this.showCatalog,
    required this.showBookmarks,
    required this.showSelection,
    required this.showSearch,
    required this.bgIndex,
    required this.brightness,
    required this.currentBookId,
    required this.chapterIndex,
    required this.pageIndex,
    required this.totalPages,
    required this.currentReadingMode,
    required this.fontSize,
    required this.lineHeight,
    required this.content,
    required this.isLoading,
    required this.error,
    required this.bilingualAlign,
    required this.isBilingualLoading,
    required this.bilingualError,
    required this.autoScrollTick,
    required this.highlights,
    required this.searchQuery,
    required this.searchCurrentIndex,
    required this.searchMatchHighlight,
    required this.letterSpacing,
    required this.paragraphSpacing,
    required this.pageMargin,
    required this.writingDirection,
    required this.pendingJumpCharOffset,
    required this.themeMode,
    required this.effectiveTotalPages,
    required this.progressText,
    required this.currentChapterTitle,
  });
}

ReaderPageBindings useReaderBindings(ReaderViewModel vm) {
  final readerTheme = useSignalValue<ReaderTheme, Signal<ReaderTheme>>(
    vm.themeMode,
  );
  final showToolbar = useSignalValue<bool, Signal<bool>>(vm.showToolbar);
  final showSettings = useSignalValue<bool, Signal<bool>>(vm.showSettings);
  final showCatalog = useSignalValue<bool, Signal<bool>>(vm.showCatalog);
  final showBookmarks = useSignalValue<bool, Signal<bool>>(vm.showBookmarks);
  final showSelection = useSignalValue<bool, Signal<bool>>(
    vm.showSelectionToolbar,
  );
  final showSearch = useSignalValue<bool, Signal<bool>>(vm.showSearch);
  final bgIndex = useSignalValue<int, Signal<int>>(vm.readerBgColorIndex);
  final brightness = useSignalValue<double, Signal<double>>(
    vm.brightnessOverlay,
  );
  final currentBookId = useSignalValue<String, Signal<String>>(vm.bookId);
  final chapterIndex = useSignalValue<int, Signal<int>>(vm.chapterIndex);
  final pageIndex = useSignalValue<int, Signal<int>>(vm.pageIndex);
  final totalPages = useSignalValue<int, Signal<int>>(vm.totalPages);
  final currentReadingMode = useSignalValue<ReadingMode, Signal<ReadingMode>>(
    vm.readingMode,
  );

  final fontSize = useSignalValue<double, Signal<double>>(vm.fontSize);
  final lineHeight = useSignalValue<double, Signal<double>>(vm.lineHeight);
  final chContent = useSignalValue<AsyncState<String>, AsyncSignal<String>>(
    vm.chapterContent,
  );
  final isLoading = useSignalValue<bool, Signal<bool>>(vm.isLoading);
  final error = useSignalValue<String?, Signal<String?>>(vm.error);
  final bState =
      useSignalValue<
        AsyncState<BilingualAlignment?>,
        AsyncSignal<BilingualAlignment?>
      >(vm.bilingualAlignment);
  final autoScrollTick = useSignalValue<int, Signal<int>>(vm.autoScrollTick);
  final highlights = useSignalValue<List<Note>, Signal<List<Note>>>(
    vm.highlights,
  );
  final searchQuery = useSignalValue<String, Signal<String>>(vm.searchQuery);
  final searchCurrentIndex = useSignalValue<int, Signal<int>>(
    vm.searchCurrentIndex,
  );
  final letterSpacing = useSignalValue<double, Signal<double>>(
    vm.letterSpacing,
  );
  final paragraphSpacing = useSignalValue<double, Signal<double>>(
    vm.paragraphSpacing,
  );
  final pageMargin = useSignalValue<double, Signal<double>>(vm.pageMargin);
  final writingDirection =
      useSignalValue<WritingDirection, Signal<WritingDirection>>(
        vm.writingDirection,
      );
  final pendingJumpCharOffset = useSignalValue<int?, Signal<int?>>(
    vm.pendingJumpCharOffset,
  );
  final progressText = useSignalValue<String, ReadonlySignal<String>>(
    vm.progressText,
  );
  final currentChapterTitle = useSignalValue<String, ReadonlySignal<String>>(
    vm.currentChapterTitle,
  );

  final themeMode = readerTheme == ReaderTheme.dark
      ? ThemeMode.dark
      : ThemeMode.light;

  return ReaderPageBindings(
    readerTheme: readerTheme,
    showToolbar: showToolbar,
    showSettings: showSettings,
    showCatalog: showCatalog,
    showBookmarks: showBookmarks,
    showSelection: showSelection,
    showSearch: showSearch,
    bgIndex: bgIndex,
    brightness: brightness,
    currentBookId: currentBookId,
    chapterIndex: chapterIndex,
    pageIndex: pageIndex,
    totalPages: totalPages,
    currentReadingMode: currentReadingMode,
    fontSize: fontSize,
    lineHeight: lineHeight,
    content: chContent.value ?? '',
    isLoading: isLoading,
    error: error,
    bilingualAlign: bState.value,
    isBilingualLoading: bState.isLoading,
    bilingualError: bState.error?.toString(),
    autoScrollTick: autoScrollTick,
    highlights: highlights,
    searchQuery: searchQuery,
    searchCurrentIndex: searchCurrentIndex,
    searchMatchHighlight: searchCurrentIndex > 0,
    letterSpacing: letterSpacing,
    paragraphSpacing: paragraphSpacing,
    pageMargin: pageMargin,
    writingDirection: writingDirection,
    pendingJumpCharOffset: pendingJumpCharOffset,
    themeMode: themeMode,
    effectiveTotalPages: math.max(1, totalPages),
    progressText: progressText,
    currentChapterTitle: currentChapterTitle,
  );
}
