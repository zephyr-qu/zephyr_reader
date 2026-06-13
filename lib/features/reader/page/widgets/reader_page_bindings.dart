import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/features/reader/application/reader_view_model.dart';
import 'package:zephyr_reader/src/rust/api/bilingual.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 阅读器页面绑定的状态集合。
///
/// 聚合 ReaderViewModel 中各信号的状态值，供渲染组件读取。
/// 减少重复的 useSignalValue 调用。
class ReaderPageBindings {
  final ReaderTheme readerTheme;
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
  final double letterSpacing;
  final double paragraphSpacing;
  final double pageMargin;
  final WritingDirection writingDirection;
  final int? pendingJumpCharOffset;
  final bool baselineAlign;
  final TextAlign textAlign;
  final ThemeMode themeMode;
  final int effectiveTotalPages;
  final String progressText;
  final String currentChapterTitle;

  const ReaderPageBindings({
    required this.readerTheme,
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
    required this.letterSpacing,
    required this.paragraphSpacing,
    required this.pageMargin,
    required this.writingDirection,
    required this.pendingJumpCharOffset,
    required this.themeMode,
    required this.effectiveTotalPages,
    required this.progressText,
    required this.baselineAlign,
    required this.textAlign,
    required this.currentChapterTitle,
  });
}

ReaderPageBindings useReaderBindings(ReaderViewModel vm) {
  final ReaderTheme readerTheme = useSignalValue(vm.config.theme.signal);
  final int bgIndex = useSignalValue(vm.config.readerBgColorIndex.signal);
  final double brightness = useSignalValue(vm.config.brightnessOverlay);
  final String currentBookId = useSignalValue(vm.bookId);
  final int chapterIndex = useSignalValue(vm.chapterIndex);
  final int pageIndex = useSignalValue(vm.pageIndex);
  final int totalPages = useSignalValue(vm.totalPages);
  final ReadingMode currentReadingMode = useSignalValue(vm.readingMode);

  final double fontSize = useSignalValue(vm.fontSizeDouble);
  final double lineHeight = useSignalValue(vm.config.lineHeight.signal);
  final AsyncState<String> chContent = useSignalValue(vm.chapterContent);
  final bool isLoading = useSignalValue(vm.isLoading);
  final String? error = useSignalValue(vm.error);
  final AsyncState<BilingualAlignment?> bState = useSignalValue(
    vm.bilingualAlignment,
  );
  final int autoScrollTick = useSignalValue(vm.autoScrollTick);
  final AsyncState<List<Note>> highlights = useSignalValue(vm.highlights);
  final double letterSpacing = useSignalValue(vm.config.letterSpacing.signal);
  final double paragraphSpacing = useSignalValue(
    vm.config.paragraphSpacing.signal,
  );
  final double pageMargin = useSignalValue(vm.config.padding.signal);
  final WritingDirection writingDirection = useSignalValue(
    vm.config.writingDirection,
  );
  final int? pendingJumpCharOffset = useSignalValue(vm.pendingJumpCharOffset);
  final String progressText = useSignalValue(vm.progressText);
  final String currentChapterTitle = useSignalValue(vm.currentChapterTitle);
  final bool baselineAlign = useSignalValue(vm.config.baselineAlign.signal);
  final TextAlign textAlign = useSignalValue(vm.config.textAlign.signal);

  final themeMode = switch (readerTheme) {
    ReaderTheme.dark => ThemeMode.dark,
    ReaderTheme.sepia => ThemeMode.light,
    ReaderTheme.light => ThemeMode.light,
  };

  return ReaderPageBindings(
    readerTheme: readerTheme,
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
    highlights: highlights.value ?? [],
    letterSpacing: letterSpacing,
    paragraphSpacing: paragraphSpacing,
    pageMargin: pageMargin,
    writingDirection: writingDirection,
    pendingJumpCharOffset: pendingJumpCharOffset,
    themeMode: themeMode,
    textAlign: textAlign,
    baselineAlign: baselineAlign,
    effectiveTotalPages: math.max(1, totalPages),
    progressText: progressText,
    currentChapterTitle: currentChapterTitle,
  );
}

/// Content-only binding — only subscribes to signals that ReaderContent needs.
/// Changes to UI state signals (showToolbar, showSettings, etc.) do NOT
/// trigger rebuilds of widgets using this binding.
ReaderPageBindings useReaderContentBindings(ReaderViewModel vm) {
  final ReaderTheme readerTheme = useSignalValue(vm.config.theme.signal);
  final String currentBookId = useSignalValue(vm.bookId);
  final int chapterIndex = useSignalValue(vm.chapterIndex);
  final int pageIndex = useSignalValue(vm.pageIndex);
  final int totalPages = useSignalValue(vm.totalPages);
  final ReadingMode currentReadingMode = useSignalValue(vm.readingMode);
  final double fontSize = useSignalValue(vm.fontSizeDouble);
  final double lineHeight = useSignalValue(vm.config.lineHeight.signal);
  final AsyncState<String> chContent = useSignalValue(vm.chapterContent);
  final bool isLoading = useSignalValue(vm.isLoading);
  final String? error = useSignalValue(vm.error);
  final AsyncState<BilingualAlignment?> bState = useSignalValue(
    vm.bilingualAlignment,
  );
  final int autoScrollTick = useSignalValue(vm.autoScrollTick);
  final AsyncState<List<Note>> highlights = useSignalValue(vm.highlights);
  final double letterSpacing = useSignalValue(vm.config.letterSpacing.signal);
  final double paragraphSpacing = useSignalValue(
    vm.config.paragraphSpacing.signal,
  );
  final double pageMargin = useSignalValue(vm.config.padding.signal);
  final WritingDirection writingDirection = useSignalValue(
    vm.config.writingDirection,
  );
  final bool baselineAlign = useSignalValue(vm.config.baselineAlign.signal);
  final TextAlign textAlign = useSignalValue(vm.config.textAlign.signal);
  final int? pendingJumpCharOffset = useSignalValue(vm.pendingJumpCharOffset);

  final themeMode = switch (readerTheme) {
    ReaderTheme.dark => ThemeMode.dark,
    ReaderTheme.sepia => ThemeMode.light,
    ReaderTheme.light => ThemeMode.light,
  };

  return ReaderPageBindings(
    readerTheme: readerTheme,
    bgIndex: 0,
    brightness: 0,
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
    highlights: highlights.value ?? [],
    letterSpacing: letterSpacing,
    paragraphSpacing: paragraphSpacing,
    baselineAlign: baselineAlign,
    pageMargin: pageMargin,
    writingDirection: writingDirection,
    pendingJumpCharOffset: pendingJumpCharOffset,
    themeMode: themeMode,
    effectiveTotalPages: math.max(1, totalPages),
    progressText: '',
    currentChapterTitle: '',
    textAlign: textAlign,
  );
}
