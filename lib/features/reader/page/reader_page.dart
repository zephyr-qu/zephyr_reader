import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/reader/custom_font_service.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/core/reader/tts_service.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';
import 'package:zephyr_reader/core/utils/haptic.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/reader/application/reader_view_model.dart';
import 'package:zephyr_reader/features/reader/data/vocabulary_marker_service.dart';
import 'package:zephyr_reader/features/reader/page/reader_page_actions.dart';

import 'reader_dictionary_panel.dart';
import 'widgets/animated_toolbar_panel.dart';
import 'widgets/bookmark_widget.dart';
import 'widgets/reader_bottom_toolbar.dart';
import 'widgets/reader_catalog_drawer.dart';
import 'widgets/reader_content.dart';
import 'package:zephyr_reader/features/reader/page/widgets/battery_indicator.dart';
import 'widgets/reader_note_sidebar.dart';
import 'widgets/reader_page_bindings.dart';
import 'widgets/reader_search_bar.dart';
import 'widgets/reader_settings_panel.dart';
import 'widgets/reader_toolbar.dart';
import 'widgets/reader_annotation_dialog.dart';
import 'widgets/reader_highlight_sheet.dart';
import 'widgets/reader_translation_dialog.dart';
import 'widgets/selection_toolbar.dart';

/// 阅读器页面。
///
/// 核心阅读界面，支持滚动/翻页/双语对照等多种阅读模式。
/// 包含工具栏、目录、书签、笔记、搜索、高亮、TTS 朗读等完整阅读功能。
/// 通过 [ReaderViewModel] 管理阅读状态。
class ReaderPage extends HookWidget {
  final String bookId;
  final int initialChapterId;
  final int initialPageIndex;

  const ReaderPage({
    super.key,
    required this.bookId,
    this.initialChapterId = 0,
    this.initialPageIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final vm = useMemoized(() => getIt<ReaderViewModel>());
    final fontRepo = useMemoized(() => getIt<FontRepository>());
    final ttsService = useMemoized(() => getIt<TtsService>());
    final config = useMemoized(() => getIt<ReaderConfig>());
    final tapLayout = useSignalValue<TapLayout, Signal<TapLayout>>(
      config.tapLayout.signal,
    );
    final scaffoldKey = useMemoized(() => GlobalKey<ScaffoldState>());
    final searchController = useTextEditingController();
    final vocabWords = useSignal<Set<String>>({});
    final selectionGlobalPos = useSignal<Offset?>(null);
    final autoHideTimer = useRef<Timer?>(null);

    // Toast → SnackBar
    useSignalEffect(() {
      final msg = vm.toastMessage.value;
      if (msg.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(msg)));
            vm.toastMessage.value = '';
          }
        });
      }
    });

    // Font → VM
    useSignalEffect(() {
      fontRepo.currentFont.value;
      vm.updateFont(fontRepo.currentFontFamily);
    });

    // 搜索面板关闭时同步清空搜索文本
    useSignalEffect(() {
      vm.showSearch.value;
      if (!vm.showSearch.value) {
        searchController.clear();
      }
    });

    // Init
    useEffect(() {
      _loadVocabularyWords(vocabWords);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final mq = MediaQuery.of(context);
        vm.pageWidth.value = mq.size.width - mq.padding.horizontal;
        vm.pageHeight.value = mq.size.height - mq.padding.vertical;
        vm.devicePixelRatio.value = mq.devicePixelRatio;
        vm.updateFont(fontRepo.currentFontFamily);
        vm.initialize(
          bookId,
          initialChapterId: initialChapterId,
          initialPageIndex: initialPageIndex,
        );
      });
      return vm.resetForNewBook;
    }, []);
    // Cancel auto-hide timer on widget dispose to prevent leak.
    useEffect(() {
      return () => autoHideTimer.value?.cancel();
    }, []);

    // ── Bind VM signals via custom Hook ──
    final b = useReaderBindings(vm);
    final fontFamily = fontRepo.currentFontFamily;

    void resetHideTimer() {
      autoHideTimer.value?.cancel();
      autoHideTimer.value = Timer(const Duration(seconds: 4), () {
        if (!context.mounted) return;
        if (b.showToolbar && !b.showSettings && !b.showSearch) {
          vm.showToolbar.value = false;
        }
      });
    }

    /// 执行 [action] 后重置自动隐藏计时器。
    void withTimer(VoidCallback action) {
      action();
      resetHideTimer();
    }

    final readerData = useMemoized(() {
      final baseTheme = Theme.of(context);
      final readerExt = switch (b.readerTheme) {
        ReaderTheme.dark => ReaderThemeExtension.dark(),
        ReaderTheme.sepia => ReaderThemeExtension.sepia(),
        ReaderTheme.light => ReaderThemeExtension.light(),
      };
      return baseTheme.copyWith(
        extensions: [readerExt, ...baseTheme.extensions.values],
      );
    }, [b.readerTheme]);

    return Theme(
      data: readerData,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          context.pop();
        },
        child: Scaffold(
          key: scaffoldKey,
          drawer: ReaderCatalogDrawer(
            chapters: vm.chapters.value.value ?? [],
            currentChapterIndex: vm.chapterIndex.value,
            onChapterSelected: vm.jumpToChapter,
          ),
          endDrawer: ReaderNoteSidebar(
            bookId: b.currentBookId,
            bookTitle: b.currentChapterTitle,
            vm: vm,
            onNoteTap: (ci, co) => vm.jumpToPosition(ci, co),
          ),
          body: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            color: b.readerTheme == ReaderTheme.dark
                ? ReaderBgColors.darkBackground
                : ReaderBgColors.presets[b.bgIndex.clamp(
                    0,
                    ReaderBgColors.presets.length - 1,
                  )],
            child: SafeArea(
              child: Builder(
                builder: (context) {
                  final textScaler = vm.config.followSystemFontScale.value
                      ? MediaQuery.textScalerOf(context)
                      : TextScaler.noScaling;
                  return Stack(
                    children: [
                      MediaQuery(
                        data: MediaQuery.of(
                          context,
                        ).copyWith(textScaler: textScaler),
                        child: ReaderContent(
                          bookId: b.currentBookId,
                          chapterId: b.chapterIndex,
                          pageIndex: b.pageIndex,
                          totalPages: b.totalPages,
                          fontSize: b.fontSize,
                          lineHeight: b.lineHeight,
                          themeMode: b.themeMode,
                          readingMode: b.currentReadingMode,
                          content: b.content,
                          isLoading: b.isLoading,
                          error: b.error,
                          bilingualAlignment: b.bilingualAlign,
                          isBilingualLoading: b.isBilingualLoading,
                          bilingualError: b.bilingualError,
                          onRequestTranslation: () => showDialog<void>(
                            context: context,
                            builder: (_) => ReaderTranslationDialog(
                              onChanged: vm.setTranslationContent,
                            ),
                          ),
                          onPageChanged: vm.loadPage,
                          onRetry: () => vm.loadChapter(
                            b.chapterIndex,
                            initialCharOffset: vm.currentCharOffset.value,
                            restartSession: false,
                          ),
                          autoScrollTick: b.autoScrollTick,
                          highlights: b.highlights,
                          onSelectionChanged: vm.updateSelection,
                          onSelectionGlobalPosition: (pos) =>
                              selectionGlobalPos.value = pos,
                          onHighlightTap: (note) => showModalBottomSheet<void>(
                            context: context,
                            builder: (_) => ReaderHighlightSheet(
                              note: note,
                              onEdit: () {
                                showDialog<void>(
                                  context: context,
                                  builder: (_) => ReaderAnnotationDialog(
                                    selectedText: note.selectedText ?? '',
                                    initialContent: note.content,
                                    onSave: (text) {
                                      final updated = note.copyWith(
                                        content: text,
                                        updatedAt: DateTime.now(),
                                      );
                                      vm.updateNote(updated);
                                    },
                                  ),
                                );
                              },
                              onDelete: () => vm.deleteNote(note.id),
                            ),
                          ),
                          fontFamily: fontFamily,
                          searchQuery: b.searchQuery,
                          searchMatchHighlight: b.searchMatchHighlight,
                          letterSpacing: b.letterSpacing,
                          paragraphSpacing: b.paragraphSpacing,
                          pageMargin: b.pageMargin,
                          writingDirection: b.writingDirection,
                          showVocabularyMark: true,
                          vocabularyWords: vocabWords.value,
                          showSentenceSplit: true,
                          bgIndex: b.bgIndex,
                          jumpToCharOffset: b.pendingJumpCharOffset,
                          onPositionChanged: vm.updateCurrentCharOffset,
                          onJumpHandled: vm.consumePendingJumpOffset,
                        ),
                      ),
                      if (b.brightness > 0)
                        IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: Alignment.center,
                                radius: 0.6,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(
                                    alpha: b.brightness * 0.5,
                                  ),
                                  Colors.black.withValues(alpha: b.brightness),
                                ],
                                stops: const [0.3, 0.7, 1.0],
                              ),
                            ),
                          ),
                        ),
                      const Positioned(
                        bottom: 12,
                        right: 0,
                        child: BatteryIndicator(),
                      ),
                      if (b.showSearch)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: ReaderSearchBar(
                            controller: searchController,
                            matchCount: vm.searchMatches.value,
                            currentIndex: vm.searchCurrentIndex.value,
                            onChanged: (q) => vm.onSearchChanged(q),
                            onNext: () => vm.nextSearchMatch(),
                            onPrev: () => vm.prevSearchMatch(),
                            onClose: () {
                              searchController.clear();
                              vm.toggleSearch();
                            },
                          ),
                        ),
                      Positioned(
                        top: b.showSearch ? 56 : 0,
                        left: 0,
                        right: 0,
                        child: AnimatedToolbarPanel(
                          visible: b.showToolbar,
                          slideBeginY: -1,
                          child: ReaderToolbar(
                            title: b.currentChapterTitle,
                            progress: b.progressText,
                            themeMode: b.themeMode,
                            onClose: () {
                              vm.resetForNewBook();
                              context.pop();
                            },
                            onToggleToolbar: () => withTimer(vm.toggleToolbar),
                          ),
                        ),
                      ),
                      if (!b.showToolbar &&
                          !b.showSearch &&
                          !b.showCatalog &&
                          !b.showBookmarks)
                        Positioned(
                          bottom: 8,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${b.pageIndex + 1} / ${b.effectiveTotalPages}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: AnimatedToolbarPanel(
                          visible: b.showToolbar,
                          slideBeginY: 1,
                          child: ReaderBottomToolbar(
                            currentPageIndex: vm.pageIndex.value,
                            totalPages: vm.totalPages.value,
                            themeMode: b.themeMode,
                            onShowSettings: () => withTimer(vm.toggleSettings),
                            onTtsToggle: () =>
                                withTimer(() => _toggleTts(vm, ttsService)),
                            isTtsPlaying: ttsService.isPlaying.value,
                            onShowCatalog: () => withTimer(
                              () => scaffoldKey.currentState?.openDrawer(),
                            ),
                            onShowNotes: () => withTimer(
                              () => scaffoldKey.currentState?.openEndDrawer(),
                            ),
                          ),
                        ),
                      ),
                      if (b.showSettings)
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: () => vm.toggleSettings(),
                            onVerticalDragEnd: (details) {
                              if (details.primaryVelocity != null &&
                                  details.primaryVelocity! > 300) {
                                vm.toggleSettings();
                              }
                            },
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      AnimatedSlide(
                        offset: b.showSettings
                            ? Offset.zero
                            : const Offset(0, 1),
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutBack,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: ReaderSettingsPanel(
                            themeMode: b.themeMode,
                            readingMode: b.currentReadingMode,
                            fontSize: vm.config.fontSize.value,
                            lineHeight: vm.config.lineHeight.value,
                            letterSpacing: vm.config.letterSpacing.value,
                            paragraphSpacing: vm.config.paragraphSpacing.value,
                            pageMargin: vm.config.pageMargin,
                            writingDirection: vm.config.writingDirection.value,
                            onReadingModeChanged: vm.setReadingMode,
                            onFontSizeChanged: vm.setFontSize,
                            onLineHeightChanged: vm.setLineHeight,
                            onThemeChanged: (tm) =>
                                config.theme.value = tm == ThemeMode.dark
                                ? ReaderTheme.dark
                                : ReaderTheme.light,
                            onLetterSpacingChanged: (v) =>
                                config.letterSpacing.value = v,
                            onParagraphSpacingChanged: (v) =>
                                config.paragraphSpacing.value = v,
                            onPageMarginChanged: (m) =>
                                config.padding.value = m,
                            onWritingDirectionChanged: (d) =>
                                vm.config.writingDirection.value = d,
                            onClose: vm.toggleSettings,
                            readerBgColorIndex:
                                vm.config.readerBgColorIndex.value,
                            onReaderBgColorChanged: (v) =>
                                config.readerBgColorIndex.value = v,
                            brightnessValue: vm.config.brightnessOverlay.value,
                            onBrightnessChanged: (v) =>
                                vm.config.brightnessOverlay.value = v.clamp(
                                  0.0,
                                  1.0,
                                ),
                            tapLayout: config.tapLayout.value,
                            onTapLayoutChanged: (layout) =>
                                config.tapLayout.value = layout,
                            followSystemFontScale:
                                config.followSystemFontScale.value,
                            onFollowSystemFontScale: (v) =>
                                config.followSystemFontScale.value = v,
                          ),
                        ),
                      ),
                      if (b.showBookmarks)
                        BookmarkWidget(
                          bookmarks: vm.bookmarks.value.value ?? [],
                          themeMode: b.themeMode,
                          onBookmarkSelected: vm.jumpToBookmark,
                          onAddBookmark: vm.addBookmark,
                          onDeleteBookmark: vm.deleteBookmark,
                          onClose: vm.toggleBookmarks,
                        ),
                      if (b.showSelection && vm.selectedText.value.isNotEmpty)
                        Positioned(
                          top: _toolbarTop(
                            MediaQuery.sizeOf(context).height,
                            selectionGlobalPos.value,
                          ),
                          left: 0,
                          right: 0,
                          child: SelectionToolbar(
                            selectedText: vm.selectedText.value,
                            onHighlight: () => vm.saveHighlight(),
                            onAnnotate: () => showDialog<void>(
                              context: context,
                              builder: (_) => ReaderAnnotationDialog(
                                selectedText: vm.selectedText.value,
                                onSave: vm.saveAnnotation,
                              ),
                            ),
                            onLookup: () => showDictionaryPanel(
                              context,
                              vm,
                              vm.selectedText.value,
                            ),
                            onAddToVocabulary: () => addToVocabulary(
                              context,
                              vm,
                              vm.selectedText.value,
                              bookId: vm.bookId.value,
                              chapterIndex: vm.chapterIndex.value,
                              charOffset: vm.selectionStart.value,
                            ),
                            onBilingualHighlight:
                                b.currentReadingMode == ReadingMode.bilingual
                                ? () => onBilingualHighlight(context, vm)
                                : null,
                            onDismiss: () => vm.clearSelection(),
                          ),
                        ),
                      if (!b.showToolbar &&
                          !b.showSelection &&
                          !b.showSearch &&
                          !b.showCatalog &&
                          !b.showBookmarks)
                        Positioned.fill(
                          child: GestureDetector(
                            onTapUp: (details) {
                              final w = context.size?.width ?? 1;
                              final third = w / 3;
                              final isLeftZone =
                                  details.localPosition.dx < third;
                              final isRightZone =
                                  details.localPosition.dx >= third * 2;
                              late final bool goBack, goForward;
                              switch (tapLayout) {
                                case TapLayout.rightHanded:
                                  goBack = isLeftZone;
                                  goForward = isRightZone;
                                case TapLayout.leftHanded:
                                  goBack = isRightZone;
                                  goForward = isLeftZone;
                              }
                              if (goBack && vm.pageIndex.value > 0) {
                                vm.previousPage();
                                hapticFeedback(HapticType.light);
                              } else if (goForward &&
                                  vm.pageIndex.value <
                                      vm.totalPages.value - 1) {
                                vm.nextPage();
                                hapticFeedback(HapticType.light);
                              } else if (!goBack && !goForward) {
                                withTimer(() {
                                  vm.toggleToolbar();
                                  hapticFeedback(HapticType.selection);
                                });
                              }
                            },
                            onHorizontalDragEnd: (details) {
                              if (details.primaryVelocity == null) return;
                              if (details.primaryVelocity! < -30) {
                                vm.nextPage();
                                hapticFeedback(HapticType.light);
                              } else if (details.primaryVelocity! > 30) {
                                vm.previousPage();
                                hapticFeedback(HapticType.light);
                              }
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _toolbarTop(double screenHeight, Offset? pos) {
    if (pos == null) return 80;
    const gap = 8.0;
    const h = 52.0;
    final above = pos.dy - h - gap;
    if (above > 0) return above;
    final below = pos.dy + gap + 20;
    return below.clamp(0, screenHeight - h);
  }

  void _toggleTts(ReaderViewModel vm, TtsService ttsService) {
    final c = vm.chapterContent.value.value;
    if (c == null || c.isEmpty) return;
    if (ttsService.isPlaying.value) {
      ttsService.stop();
    } else {
      ttsService.speak(c);
    }
    hapticFeedback(HapticType.medium);
  }

  Future<void> _loadVocabularyWords(Signal<Set<String>> out) async {
    final service = getIt<VocabularyMarkerService>();
    await service.ensureLoaded();
    out.value = <String>{}
      ..addAll(service.cet6)
      ..addAll(service.ielts)
      ..addAll(service.toefl);
  }
}
