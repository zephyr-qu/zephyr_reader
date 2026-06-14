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
  final int effectiveTotalPages;
  final String progressText;
  final String currentChapterTitle;
  final String selectedText;
  final int selectionStart;
  final int numChapters;

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
    this.autoScrollTick = 0,
    required this.highlights,
    required this.letterSpacing,
    required this.paragraphSpacing,
    required this.pageMargin,
    required this.writingDirection,
    required this.pendingJumpCharOffset,
    required this.effectiveTotalPages,
    required this.progressText,
    required this.baselineAlign,
    required this.textAlign,
    required this.currentChapterTitle,
    required this.selectedText,
    required this.selectionStart,
    required this.numChapters,
  });
}

ReaderPageBindings useReaderBindings(ReaderViewModel vm) {
  final ReaderTheme readerTheme = useSignalValue(vm.config.theme.signal);
  final int bgIndex = useSignalValue(vm.config.readerBgColorIndex.signal);
  final double brightness = useSignalValue(vm.config.brightnessOverlay);
  final String currentBookId = useSignalValue(vm.state.bookId);
  final int chapterIndex = useSignalValue(vm.state.chapterIndex);
  final int pageIndex = useSignalValue(vm.chapterManager.pageIndex);
  final int totalPages = useSignalValue(vm.chapterManager.totalPages);
  final ReadingMode currentReadingMode = useSignalValue(vm.state.readingMode);

  final double fontSize = useSignalValue(vm.fontSizeDouble);
  final double lineHeight = useSignalValue(vm.config.lineHeight.signal);
  final AsyncState<String> chContent = useSignalValue(vm.state.chapterContent);
  final bool isLoading = useSignalValue(vm.chapterManager.isLoading);
  final String? error = useSignalValue(vm.chapterManager.error);
  final AsyncState<BilingualAlignment?> bState = useSignalValue(
    vm.translation.bilingualAlignment,
  );
  final int autoScrollTick = useSignalValue(vm.chapterManager.autoScrollTick);
  final AsyncState<List<Note>> highlights = useSignalValue(vm.annotations.highlights);
  final double letterSpacing = useSignalValue(vm.config.letterSpacing.signal);
  final double paragraphSpacing = useSignalValue(
    vm.config.paragraphSpacing.signal,
  );
  final double pageMargin = useSignalValue(vm.config.padding.signal);
  final WritingDirection writingDirection = useSignalValue(
    vm.config.writingDirection,
  );
  final int? pendingJumpCharOffset = useSignalValue(vm.state.pendingJumpCharOffset);
  final String progressText = useSignalValue(vm.chapterManager.progressText);
  final String currentChapterTitle = useSignalValue(vm.chapterManager.currentChapterTitle);
  final bool baselineAlign = useSignalValue(vm.config.baselineAlign.signal);
  final TextAlign textAlign = useSignalValue(vm.config.textAlign.signal);
  final String selectedText = useSignalValue(vm.annotations.selectedText);
  final int selectionStart = useSignalValue(vm.annotations.selectionStart);
  final chaptersResult = useSignalValue(vm.chapterManager.chapters);
  final int numChapters = (chaptersResult as AsyncState<List<Chapter>>).value?.length ?? 0;


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
    textAlign: textAlign,
    baselineAlign: baselineAlign,
    effectiveTotalPages: math.max(1, totalPages),
    progressText: progressText,
    currentChapterTitle: currentChapterTitle,
    selectedText: selectedText,
    selectionStart: selectionStart,
    numChapters: numChapters,
  );
}

/// Content-only binding — only subscribes to signals that ReaderContent needs.
/// Changes to UI state signals (showToolbar, showSettings, etc.) do NOT
/// trigger rebuilds of widgets using this binding.
ReaderPageBindings useReaderContentBindings(ReaderViewModel vm) {
  final ReaderTheme readerTheme = useSignalValue(vm.config.theme.signal);
  final String currentBookId = useSignalValue(vm.state.bookId);
  final int chapterIndex = useSignalValue(vm.state.chapterIndex);
  final int pageIndex = useSignalValue(vm.chapterManager.pageIndex);
  final int totalPages = useSignalValue(vm.chapterManager.totalPages);
  final ReadingMode currentReadingMode = useSignalValue(vm.state.readingMode);
  final double fontSize = useSignalValue(vm.fontSizeDouble);
  final double lineHeight = useSignalValue(vm.config.lineHeight.signal);
  final AsyncState<String> chContent = useSignalValue(vm.state.chapterContent);
  final bool isLoading = useSignalValue(vm.chapterManager.isLoading);
  final String? error = useSignalValue(vm.chapterManager.error);
  final AsyncState<BilingualAlignment?> bState = useSignalValue(
    vm.translation.bilingualAlignment,
  );
  // autoScrollTick intentionally excluded — ReaderContent subscribes via local useEffect
  // to avoid triggering rebuilds of widgets using this binding on every tick.
  final AsyncState<List<Note>> highlights = useSignalValue(vm.annotations.highlights);
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
  final int? pendingJumpCharOffset = useSignalValue(vm.state.pendingJumpCharOffset);
  final chaptersResult = useSignalValue(vm.chapterManager.chapters);
  final int numChapters = (chaptersResult as AsyncState<List<Chapter>>).value?.length ?? 0;


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
    // autoScrollTick excluded: consumer subscribes locally
    highlights: highlights.value ?? [],
    letterSpacing: letterSpacing,
    paragraphSpacing: paragraphSpacing,
    baselineAlign: baselineAlign,
    pageMargin: pageMargin,
    writingDirection: writingDirection,
    pendingJumpCharOffset: pendingJumpCharOffset,
    effectiveTotalPages: math.max(1, totalPages),
    progressText: '',
    currentChapterTitle: '',
    selectedText: '',
    selectionStart: 0,
    numChapters: numChapters,
    textAlign: textAlign,
  );
}
