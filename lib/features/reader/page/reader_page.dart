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
import 'package:zephyr_reader/features/profile/application/tts_settings_view_model.dart';
import 'package:zephyr_reader/features/reader/data/repositories/rust_reader_repository.dart';
import 'package:zephyr_reader/features/reader/page/reader_page_actions.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

import 'reader_dictionary_panel.dart';
import 'widgets/animated_toolbar_panel.dart';
import 'widgets/bookmark_widget.dart';
import 'widgets/brightness_mask.dart';
import 'widgets/page_indicator.dart';
import 'widgets/reader_bottom_toolbar.dart';
import 'widgets/reader_catalog_drawer.dart';
import 'widgets/reader_content.dart';
import 'package:zephyr_reader/features/reader/page/widgets/battery_indicator.dart';
import 'widgets/tap_zone.dart';
import 'widgets/reader_note_sidebar.dart';
import 'widgets/reader_page_bindings.dart';
import 'widgets/reader_search_bar.dart';
import 'widgets/reader_settings_overlay.dart';
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
    final readRepo = useMemoized(() => getIt<ReaderRepository>());
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
    final activePanel = useState<ReaderPanelType?>(null);

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
        vm.pageWidth = mq.size.width - mq.padding.horizontal;
        vm.pageHeight = mq.size.height - mq.padding.vertical;
        vm.devicePixelRatio = mq.devicePixelRatio;
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
    final l10n = AppLocalizations.of(context)!;

    final b = useReaderBindings(vm);
    const brightnessPresets = [0.0, 0.3, 0.5, 0.7];

    void cycleBrightness() {
      final current = vm.config.brightnessOverlay.value;
      final idx = brightnessPresets.indexWhere(
        (p) => (p - current).abs() < 0.05,
      );
      final nextIdx = idx == -1 ? 0 : (idx + 1) % brightnessPresets.length;
      vm.config.brightnessOverlay.value = brightnessPresets[nextIdx];
    }

    final fontFamily = fontRepo.currentFontFamily;

    void resetHideTimer() {
      autoHideTimer.value?.cancel();
      if (!context.mounted) return;
      autoHideTimer.value = Timer(const Duration(seconds: 4), () {
        if (!context.mounted) return;
        if (b.showToolbar && activePanel.value == null && !b.showSearch) {
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

    // ── 提取的 Stack children 构建方法 ──

    List<Widget> buildContentArea() {
      final textScaler = vm.config.followSystemFontScale.value
          ? MediaQuery.textScalerOf(context)
          : TextScaler.noScaling;
      return [
        MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: ReaderContent(
            repo: readRepo,
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
            onRequestTranslation: () => showDialog<void>(
              context: context,
              builder: (_) => ReaderTranslationDialog(
                onChanged: vm.setTranslationContent,
                translationConfigured: vm.isTranslationConfigured,
                onTranslateWithApi: () {
                  Navigator.of(context).pop();
                  unawaited(vm.translateChapter());
                },
              ),
            ),
            onRetryTranslation: () => unawaited(vm.translateChapter()),
            onPageChanged: vm.loadPage,
            onRetry: () => vm.loadChapter(
              b.chapterIndex,
              initialCharOffset: vm.currentCharOffset.value,
              restartSession: false,
            ),
            autoScrollTick: b.autoScrollTick,
            highlights: b.highlights,
            onSelectionChanged: vm.updateSelection,
            onSelectionGlobalPosition: (pos) => selectionGlobalPos.value = pos,
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
                        vm.updateNote(updated, l10n);
                      },
                    ),
                  );
                },
                onDelete: () => vm.deleteNote(note.id, l10n),
              ),
            ),
            fontFamily: fontFamily,
            searchQuery: b.searchQuery,
            searchMatchHighlight: b.searchMatchHighlight,
            letterSpacing: b.letterSpacing,
            paragraphSpacing: b.paragraphSpacing,
            pageMargin: b.pageMargin,
            writingDirection: b.writingDirection,
            baselineAlign: b.baselineAlign,
            showVocabularyMark: true,
            vocabularyWords: vocabWords.value,
            showSentenceSplit: true,
            bgIndex: b.bgIndex,
            jumpToCharOffset: b.pendingJumpCharOffset,
            onPositionChanged: vm.updateCurrentCharOffset,
            onJumpHandled: vm.consumePendingJumpOffset,
            onReachEnd: () => unawaited(vm.nextChapter()),
          ),
        ),
        BrightnessMask(
          brightness: b.brightness,
          readingMode: b.currentReadingMode,
          onDoubleTap: cycleBrightness,
        ),
        Positioned(
          bottom: 12,
          right: 0,
          child: BatteryIndicator(progressText: b.progressText),
        ),
      ];
    }

    Widget buildSearchBar() {
      return Positioned(
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
      );
    }

    Widget buildTopToolbar() {
      return Positioned(
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
            onToggleMore: () => withTimer(() {
              activePanel.value = activePanel.value == ReaderPanelType.more
                  ? null
                  : ReaderPanelType.more;
            }),
          ),
        ),
      );
    }

    List<Widget> buildBottomArea() {
      return [
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: AnimatedToolbarPanel(
            visible: b.showToolbar,
            slideBeginY: 1,
            child: ReaderBottomToolbar(
              onShowCatalog: () =>
                  withTimer(() => scaffoldKey.currentState?.openDrawer()),
              onShowNotes: () =>
                  withTimer(() => scaffoldKey.currentState?.openEndDrawer()),
              onToggleTypesetting: () => withTimer(() {
                activePanel.value =
                    activePanel.value == ReaderPanelType.typesetting
                    ? null
                    : ReaderPanelType.typesetting;
              }),
              onToggleDisplay: () => withTimer(() {
                activePanel.value = activePanel.value == ReaderPanelType.display
                    ? null
                    : ReaderPanelType.display;
              }),
              onToggleTts: () => withTimer(() {
                activePanel.value = activePanel.value == ReaderPanelType.tts
                    ? null
                    : ReaderPanelType.tts;
              }),
            ),
          ),
        ),
        if (activePanel.value != null)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => activePanel.value = null,
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity != null &&
                    details.primaryVelocity! > 300) {
                  activePanel.value = null;
                }
              },
              child: Container(color: Colors.black.withValues(alpha: 0.3)),
            ),
          ),
        AnimatedSlide(
          offset: activePanel.value != null ? Offset.zero : const Offset(0, 1),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: activePanel.value != null
                ? ReaderSettingsOverlay(
                    panelType: activePanel.value!,
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
                    onPageMarginChanged: (m) => config.padding.value = m,
                    onWritingDirectionChanged: (d) =>
                        vm.config.writingDirection.value = d,
                    onClose: () => activePanel.value = null,
                    readerBgColorIndex: vm.config.readerBgColorIndex.value,
                    onReaderBgColorChanged: (v) =>
                        config.readerBgColorIndex.value = v,
                    brightnessValue: vm.config.brightnessOverlay.value,
                    onBrightnessChanged: (v) =>
                        vm.config.brightnessOverlay.value = v.clamp(0.0, 1.0),
                    tapLayout: config.tapLayout.value,
                    onTapLayoutChanged: (layout) =>
                        config.tapLayout.value = layout,
                    followSystemFontScale: config.followSystemFontScale.value,
                    onFollowSystemFontScale: (v) =>
                        config.followSystemFontScale.value = v,
                    autoScroll: config.autoScroll.value,
                    autoScrollSpeed: config.autoScrollSpeed.value,
                    onAutoScrollChanged: (v) => config.autoScroll.value = v,
                    onAutoScrollSpeedChanged: (v) =>
                        config.autoScrollSpeed.value = v.round(),
                    isTtsPlaying: ttsService.isPlaying.value,
                    isTtsPaused: ttsService.isPaused.value,
                    onTtsToggle: () => _toggleTts(vm, ttsService),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ];
    }

    Widget buildBookmarks() {
      return BookmarkWidget(
        bookmarks: vm.bookmarks.value.value ?? [],
        themeMode: b.themeMode,
        onBookmarkSelected: vm.jumpToBookmark,
        onAddBookmark: vm.addBookmark,
        onDeleteBookmark: vm.deleteBookmark,
        onClose: vm.toggleBookmarks,
      );
    }

    Widget buildSelectionToolbar() {
      return Positioned(
        top: _toolbarTop(
          MediaQuery.sizeOf(context).height,
          selectionGlobalPos.value,
        ),
        left: 0,
        right: 0,
        child: SelectionToolbar(
          selectedText: vm.selectedText.value,
          onHighlight: () => vm.saveHighlight(l10n),
          onAnnotate: () => showDialog<void>(
            context: context,
            builder: (_) => ReaderAnnotationDialog(
              selectedText: vm.selectedText.value,
              onSave: (text) => vm.saveAnnotation(text, l10n),
            ),
          ),
          onLookup: () =>
              showDictionaryPanel(context, vm, vm.selectedText.value),
          onAddToVocabulary: () => addToVocabulary(
            context,
            vm,
            vm.selectedText.value,
            bookId: vm.bookId.value,
            chapterIndex: vm.chapterIndex.value,
            charOffset: vm.selectionStart.value,
          ),
          onBilingualHighlight: b.currentReadingMode == ReadingMode.bilingual
              ? () => onBilingualHighlight(context, vm)
              : null,
          onDismiss: () => vm.clearSelection(),
        ),
      );
    }

    return Theme(
      data: readerData,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          // Close drawer/endDrawer first if open, don't pop yet
          final scaffold = scaffoldKey.currentState;
          if (scaffold != null && scaffold.isDrawerOpen) {
            scaffold.closeDrawer();
            return;
          }
          if (scaffold != null && scaffold.isEndDrawerOpen) {
            scaffold.closeEndDrawer();
            return;
          }
          // 离开页面前清理定时器和 VM 状态，防止 Timer 泄漏
          autoHideTimer.value?.cancel();
          vm.resetForNewBook();
          context.pop();
        },
        child: Scaffold(
          key: scaffoldKey,
          drawerEnableOpenDragGesture: false,
          endDrawerEnableOpenDragGesture: false,
          drawerEdgeDragWidth: 0,
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
            child: Builder(
              builder: (context) {
                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    SafeArea(
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          ...buildContentArea(),
                          PageIndicator(
                            pageIndex: b.pageIndex,
                            totalPages: b.effectiveTotalPages,
                            visible: false,
                          ),
                          ...buildBottomArea(),
                          if (b.showSelection &&
                              vm.selectedText.value.isNotEmpty)
                            buildSelectionToolbar(),
                        ],
                      ),
                    ),
                    if (b.showSearch) buildSearchBar(),
                    buildTopToolbar(),
                    if (b.showBookmarks)
                      Positioned.fill(child: SafeArea(child: buildBookmarks())),
                    if (!b.showToolbar &&
                        !b.showSelection &&
                        !b.showSearch &&
                        !b.showCatalog &&
                        !b.showBookmarks &&
                        b.currentReadingMode != ReadingMode.pageTurn)
                      TapZone(
                        tapLayout: tapLayout,
                        pageIndex: vm.pageIndex.value,
                        totalPages: vm.totalPages.value,
                        onPreviousPage: () {
                          unawaited(vm.previousPage());
                          hapticFeedback(HapticType.light);
                        },
                        onNextPage: () {
                          unawaited(vm.nextPage());
                          hapticFeedback(HapticType.light);
                        },
                        onCenterTap: () => withTimer(() {
                          vm.toggleToolbar();
                          hapticFeedback(HapticType.selection);
                        }),
                      ),
                  ],
                );
              },
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
    if (ttsService.isPlaying.value && !ttsService.isPaused.value) {
      // Playing → Pause
      ttsService.pause();
    } else if (ttsService.isPaused.value) {
      // Paused → Resume
      ttsService.resume();
    } else {
      // Stopped → Start
      _startTts(vm, ttsService);
    }
    hapticFeedback(HapticType.medium);
  }

  void _startTts(ReaderViewModel vm, TtsService ttsService) {
    final c = vm.chapterContent.value.value;
    if (c == null || c.isEmpty) return;
    final ttsSettings = getIt<TtsSettingsViewModel>();
    final autoPage = ttsSettings.autoPage.value;
    ttsService.speak(
      c,
      originalOnly: ttsSettings.originalOnly.value,
      bilingualAlternate: ttsSettings.bilingualAlternate.value,
      switchIntervalMs: ttsSettings.switchInterval.value,
      onComplete: autoPage ? () => vm.nextPage() : null,
    );
  }

  Future<void> _loadVocabularyWords(Signal<Set<String>> out) async {
    final service = getIt<VocabularyMarkerService>();
    await service.ensureLoaded();
    out.value = service.allWords.toSet();
  }
}
