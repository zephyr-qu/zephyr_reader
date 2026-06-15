import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/reader/custom_font_service.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/core/reader/tts_service.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/core/theme/anim_tokens.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/profile/application/tts_settings_view_model.dart';
import 'package:zephyr_reader/features/reader/application/reader_view_model.dart';
import 'package:zephyr_reader/features/reader/data/repositories/rust_reader_repository.dart';
import 'package:zephyr_reader/features/reader/data/vocabulary_marker_service.dart';
import 'package:zephyr_reader/features/reader/page/bookmarks/reader_annotation_dialog.dart';
import 'package:zephyr_reader/features/reader/page/bookmarks/reader_highlight_sheet.dart';
import 'package:zephyr_reader/features/reader/page/bookmarks/reader_note_sidebar.dart';
import 'package:zephyr_reader/features/reader/page/navigation/reader_navigation_drawer.dart';
import 'package:zephyr_reader/features/reader/page/reader_page_actions.dart';
import 'package:zephyr_reader/features/reader/page/renderer/bilingual_renderer.dart';
import 'package:zephyr_reader/features/reader/page/renderer/paginated_renderer.dart';
import 'package:zephyr_reader/features/reader/page/renderer/reader_render_config.dart';
import 'package:zephyr_reader/features/reader/page/renderer/scroll_mode_renderer.dart';
import 'package:zephyr_reader/features/reader/page/settings/reader_settings_overlay.dart';
import 'package:zephyr_reader/features/reader/page/toolbar/animated_toolbar_panel.dart';
import 'package:zephyr_reader/features/reader/page/toolbar/reader_toolbar.dart';
import 'package:zephyr_reader/features/reader/page/touch/selection_toolbar.dart';
import 'package:zephyr_reader/features/reader/page/touch/tap_zone.dart';
import 'package:zephyr_reader/features/reader/page/ui/battery_indicator.dart';
import 'package:zephyr_reader/features/reader/page/ui/brightness_mask.dart';
import 'package:zephyr_reader/features/reader/page/widgets/reader_content.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/api/bilingual.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

import 'reader_dictionary_panel.dart';
import 'widgets/reader_translation_dialog.dart';

/// 阅读器页面。
///
/// 核心阅读界面，支持滚动/翻页/双语对照等多种阅读模式。
/// 包含工具栏、目录、书签、笔记、搜索、高亮、TTS 朗读等完整阅读功能。
/// 通过 [ReaderViewModel] 管理阅读状态。
class ReaderPage extends HookWidget {
  final String bookId;
  final int initialChapterId;

  const ReaderPage({
    super.key,
    required this.bookId,
    this.initialChapterId = 0,
  });

  @override
  Widget build(BuildContext context) {
    final vm = useMemoized(() => getIt<ReaderViewModel>());
    final fontRepo = useMemoized(() => getIt<FontRepository>());
    final readRepo = useMemoized(() => getIt<ReaderRepository>());
    final ttsService = useMemoized(() => getIt<TtsService>());
    final config = useMemoized(() => getIt<ReaderConfig>());
    final ttsVm = useMemoized(() => getIt<TtsSettingsViewModel>());
    final TapLayout tapLayout = useSignalValue(config.tapLayout.signal);
    final scaffoldKey = useMemoized(() => GlobalKey<ScaffoldState>());

    final vocabWords = useSignal<Set<String>>({});
    final selectionGlobalPos = useSignal<Offset?>(null);
    final autoHideTimer = useRef<Timer?>(null);
    final activePanel = useState<ReaderPanelType?>(null);
    final showToolbar = useSignal(false);
    final showSelection = useSignalValue<String, Signal<String>>(
      vm.annotations.selectedText,
    ).isNotEmpty;

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

    // Font → VM：依赖追踪 fontRepo.currentFont
    useSignalEffect(() {
      vm.chapterManager.updateFont(fontRepo.currentFontFamily);
    });

    // Init
    useEffect(() {
      _loadVocabularyWords(vocabWords);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final mq = MediaQuery.of(context);
        vm.chapterManager.pageWidth = mq.size.width - mq.padding.horizontal;
        vm.chapterManager.pageHeight = mq.size.height - mq.padding.vertical;
        vm.chapterManager.devicePixelRatio = mq.devicePixelRatio;
        vm.chapterManager.updateFont(fontRepo.currentFontFamily);
        vm.initialize(bookId, initialChapterId: initialChapterId);
      });
      return () {
        vm.resetForNewBook();
      };
    }, []);
    // Cancel auto-hide timer on widget dispose to prevent leak.
    useEffect(() {
      return () => autoHideTimer.value?.cancel();
    }, []);

    final l10n = AppLocalizations.of(context)!;
    // ── VM 信号订阅清单 ──
    final ReaderTheme bReadertheme = useSignalValue(vm.config.theme.signal);
    final int bBgindex = useSignalValue(vm.config.readerBgColorIndex.signal);
    final double bBrightness = useSignalValue(vm.config.brightnessOverlay);
    final String bCurrentbookid = useSignalValue(vm.state.bookId);
    final int bChapterindex = useSignalValue(vm.state.chapterIndex);
    final int bPageindex = useSignalValue(vm.chapterManager.pageIndex);
    final int bTotalpages = useSignalValue(vm.chapterManager.totalPages);
    final ReadingMode bCurrentreadingmode = useSignalValue(
      vm.state.readingMode,
    );
    final double bFontsize = useSignalValue(vm.config.fontSize.signal);
    final double bLineheight = useSignalValue(vm.config.lineHeight.signal);
    final AsyncState<String> chContent = useSignalValue(
      vm.state.chapterContent,
    );
    final String bContent = chContent.value ?? '';
    final bool bIsloading = useSignalValue(vm.chapterManager.isLoading);
    final String? bError = useSignalValue(vm.chapterManager.error);
    final AsyncState<BilingualAlignment?> bState = useSignalValue(
      vm.translation.bilingualAlignment,
    );
    final BilingualAlignment? bBilingualalign = bState.value;
    final bool bIsbilingualloading = bState.isLoading;
    final int bAutoscrolltick = useSignalValue(
      vm.chapterManager.autoScrollTick,
    );
    final AsyncState<List<Note>> highlightsState = useSignalValue(
      vm.annotations.highlights,
    );
    final List<Note> bHighlights = highlightsState.value ?? [];
    final double bLetterspacing = useSignalValue(
      vm.config.letterSpacing.signal,
    );
    final double bParagraphspacing = useSignalValue(
      vm.config.paragraphSpacing.signal,
    );
    final double bPagemargin = useSignalValue(vm.config.padding.signal);
    final WritingDirection bWritingdirection = useSignalValue(
      vm.config.writingDirection,
    );
    final int? bPendingjumpcharoffset = useSignalValue(
      vm.state.pendingJumpCharOffset,
    );
    final String bProgresstext = useSignalValue(
      vm.chapterManager.progressText,
    );
    final String bCurrentchaptertitle = useSignalValue(
      vm.chapterManager.currentChapterTitle,
    );
    final bool bBaselinealign = useSignalValue(vm.config.baselineAlign.signal);
    final TextAlign bTextalign = useSignalValue(vm.config.textAlign.signal);
    final String bSelectedtext = useSignalValue(vm.annotations.selectedText);
    final int bSelectionstart = useSignalValue(vm.annotations.selectionStart);
    final AsyncState<List<Chapter>> chaptersState = useSignalValue(
      vm.chapterManager.chapters,
    );
    final int bNumchapters = (chaptersState.value as List?)?.length ?? 0;
    final themeMode = switch (bReadertheme) {
      ReaderTheme.dark => ThemeMode.dark,
      ReaderTheme.sepia => ThemeMode.light,
      ReaderTheme.light => ThemeMode.light,
    };

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
        if (showToolbar.value && activePanel.value == null) {
          showToolbar.value = false;
        }
      });
    }

    /// 执行 [action] 后重置自动隐藏计时器。
    void withTimer(VoidCallback action) {
      action();
      resetHideTimer();
    }

    final baseTheme = Theme.of(context);
    final readerExt = ReaderThemeExtension.resolve(bReadertheme);
    final readerData = baseTheme.copyWith(
      extensions: [readerExt, ...baseTheme.extensions.values],
    );

    // ── 提取的 Stack children 构建方法 ──

    List<Widget> buildContentArea() {
      final textScaler = vm.config.followSystemFontScale.value
          ? MediaQuery.textScalerOf(context)
          : TextScaler.noScaling;
      return [
        MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: Builder(
            builder: (context) {
              final renderConfig = ReaderRenderConfig(
                textColor: ReaderContent.getTextColor(themeMode),
                backgroundColor: ReaderContent.getBackgroundColor(
                  themeMode,
                  bBgindex,
                ),
                fontSize: bFontsize,
                lineHeight: bLineheight,
                fontFamily: fontFamily,
                letterSpacing: bLetterspacing,
                paragraphSpacing: bParagraphspacing,
                pageMargin: bPagemargin,
                showVocabularyMark: true,
                vocabularyWords: vocabWords.value,
                baselineAlign: bBaselinealign,
                textAlign: bTextalign,
              );
              Future<void> onHighlightTap(Note note) => showModalBottomSheet<void>(
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
              );
              return ReaderContent(
                repo: readRepo,
                bookId: bCurrentbookid,
                chapterId: bChapterindex,
                pageIndex: bPageindex,
                totalPages: bTotalpages,
                renderConfig: renderConfig,
                readingMode: bCurrentreadingmode,
                content: bContent,
                isLoading: bIsloading,
                error: bError,
                hasNextChapter: bChapterindex < bNumchapters - 1,
                scrollBuilder: (_, sc) => ScrollModeRenderer(
                  config: renderConfig,
                  scrollController: sc,
                  repo: readRepo,
                  bookId: bCurrentbookid,
                  chapterId: bChapterindex,
                  content: bContent,
                  highlights: bHighlights,
                  onHighlightTap: onHighlightTap,
                  onSelectionChanged: vm.annotations.updateSelection,
                  onSelectionGlobalPosition: (pos) =>
                      selectionGlobalPos.value = pos,
                  writingDirection: bWritingdirection,
                  showSentenceSplit: true,
                ),
                bilingualBuilder: (_, sc, pairs) => BilingualModeRenderer(
                  config: renderConfig,
                  scrollController: sc,
                  bilingualPairs: pairs,
                  isBilingualLoading: bIsbilingualloading,
                  bilingualAlignment: bBilingualalign,
                  highlights: bHighlights,
                  onRequestTranslation: () => showDialog<void>(
                    context: context,
                    builder: (_) => ReaderTranslationDialog(
                      onChanged: vm.translation.setTranslationContent,
                      translationConfigured: vm.translation.isConfigured,
                      onTranslateWithApi: () {
                        Navigator.of(context).pop();
                        unawaited(vm.translation.translateChapter());
                      },
                    ),
                  ),
                  onRetryTranslation: () =>
                      unawaited(vm.translation.translateChapter()),
                  onHighlightTap: onHighlightTap,
                  onSelectionChanged: vm.annotations.updateSelection,
                  onSelectionGlobalPosition: (pos) =>
                      selectionGlobalPos.value = pos,
                  writingDirection: bWritingdirection,
                ),
                paginatedBuilder: (_, pc) => PaginatedModeRenderer(
                  config: renderConfig,
                  pageController: pc,
                  repo: readRepo,
                  bookId: bCurrentbookid,
                  chapterId: bChapterindex,
                  pageIndex: bPageindex,
                  content: bContent,
                  highlights: bHighlights,
                  readingMode: bCurrentreadingmode,
                  onHighlightTap: onHighlightTap,
                  onSelectionChanged: vm.annotations.updateSelection,
                  onSelectionGlobalPosition: (pos) =>
                      selectionGlobalPos.value = pos,
                  onPageChanged: vm.loadPage,
                  onPositionChanged: vm.chapterManager.updateCurrentCharOffset,
                  writingDirection: bWritingdirection,
                ),
                onPageChanged: vm.loadPage,
                onRetry: () => vm.loadChapter(
                  bChapterindex,
                  initialCharOffset: vm.state.currentCharOffset.value,
                  restartSession: false,
                ),
                autoScrollTick: bAutoscrolltick,
                highlights: bHighlights,
                onSelectionChanged: vm.annotations.updateSelection,
                onSelectionGlobalPosition: (pos) =>
                    selectionGlobalPos.value = pos,
                writingDirection: bWritingdirection,
                jumpToCharOffset: bPendingjumpcharoffset,
                onPositionChanged: vm.chapterManager.updateCurrentCharOffset,
                onJumpHandled: vm.chapterManager.consumePendingJumpOffset,
                onReachEnd: () => unawaited(vm.chapterManager.nextChapter()),
              );
            },
          ),
        ),
        BrightnessMask(
          brightness: bBrightness,
          readingMode: bCurrentreadingmode,
          onDoubleTap: cycleBrightness,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: BatteryIndicator(progressText: bProgresstext),
        ),
      ];
    }

    Widget buildTopToolbar() {
      return Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: AnimatedToolbarPanel(
          visible: showToolbar.value,
          slideBeginY: -1,
          child: ReaderToolbar(
            title: bCurrentchaptertitle,
            progress: bProgresstext,
            themeMode: themeMode,
            onClose: () {
              vm.resetForNewBook();
              context.pop();
            },
            onToggleToolbar: () =>
                withTimer(() => showToolbar.value = !showToolbar.value),
            onSearchBook: () {
              activePanel.value = null;
              showToolbar.value = false;
              context.pushNamed(
                AppRoute.bookSearch.name,
                queryParameters: {'bookId': bCurrentbookid},
              );
            },
            onToggleBookmarks: () =>
                withTimer(vm.toggleBookmarkAtCurrentPosition),
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
          duration: AnimTokens.slow,
          curve: Curves.easeOut,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: activePanel.value != null
                ? ReaderSettingsOverlay(
                    panelType: activePanel.value!,
                    config: config,
                    readingMode: bCurrentreadingmode,
                    fontRepo: fontRepo,
                    isTtsPlaying: ttsService.isPlaying.value,
                    isTtsPaused: ttsService.isPaused.value,
                    onReadingModeChanged: vm.setReadingMode,
                    onFontSizeChanged: vm.setFontSize,
                    onLineHeightChanged: vm.setLineHeight,
                    onPageMarginChanged: (m) => vm.setPageMargin(m),
                    onTtsToggle: () => _toggleTts(vm, ttsService),
                    ttsVm: ttsVm,
                    onClose: () => activePanel.value = null,
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ];
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
          selectedText: bSelectedtext,
          onHighlight: () => vm.saveHighlight(l10n),
          onAnnotate: () => showDialog<void>(
            context: context,
            builder: (_) => ReaderAnnotationDialog(
              selectedText: bSelectedtext,
              onSave: (text) => vm.saveAnnotation(text, l10n),
            ),
          ),
          onLookup: () => showDictionaryPanel(context, vm, bSelectedtext),
          onAddToVocabulary: () => addToVocabulary(
            context,
            vm,
            bSelectedtext,
            bookId: vm.state.bookId.value,
            chapterIndex: vm.state.chapterIndex.value,
            charOffset: bSelectionstart,
          ),
          onBilingualHighlight: bCurrentreadingmode == ReadingMode.bilingual
              ? () => onBilingualHighlight(context, vm)
              : null,
          onDismiss: () => vm.annotations.clearSelection(),
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
          drawer: ReaderNavigationDrawer(
            chapters: vm.chapterManager.chapters.value.value ?? [],
            currentChapterIndex: bChapterindex,
            onChapterSelected: (idx) {
              vm.chapterManager.jumpToChapter(idx);
            },
            bookmarks: vm.bookmarks.bookmarks.value.value ?? [],
            onBookmarkSelected: (bm) => vm.jumpToBookmark(bm),
            onAddBookmark: () => vm.toggleBookmarkAtCurrentPosition(),
            onDeleteBookmark: (id) => vm.bookmarks.deleteBookmark(id),
            themeMode: themeMode,
            bookId: bCurrentbookid,
          ),
          endDrawer: ReaderNoteSidebar(
            bookId: bCurrentbookid,
            bookTitle: bCurrentchaptertitle,
            vm: vm,
            onNoteTap: (ci, co) => vm.chapterManager.jumpToPosition(ci, co),
          ),
          body: AnimatedContainer(
            duration: AnimTokens.slow,
            curve: Curves.easeInOut,
            color: bReadertheme == ReaderTheme.dark
                ? ReaderBgColors.darkBackground
                : ReaderBgColors.presets[bBgindex.clamp(
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
                          ...buildBottomArea(),
                          if (showSelection) buildSelectionToolbar(),
                        ],
                      ),
                    ),
                    buildTopToolbar(),
                    if (!showToolbar.value &&
                        !showSelection &&
                        bCurrentreadingmode != ReadingMode.pageTurn)
                      TapZone(
                        tapLayout: tapLayout,
                        pageIndex: bPageindex,
                        totalPages: bTotalpages,
                        onPreviousPage: () {
                          unawaited(vm.chapterManager.previousPage());
                          HapticFeedback.lightImpact();
                        },
                        onNextPage: () {
                          unawaited(vm.chapterManager.nextPage());
                          HapticFeedback.lightImpact();
                        },
                        onCenterTap: () => withTimer(() {
                          showToolbar.value = !showToolbar.value;
                          HapticFeedback.selectionClick();
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
    final c = vm.state.chapterContent.value.value;
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
    HapticFeedback.mediumImpact();
  }

  void _startTts(ReaderViewModel vm, TtsService ttsService) {
    final c = vm.state.chapterContent.value.value;
    if (c == null || c.isEmpty) return;
    final ttsSettings = getIt<TtsSettingsViewModel>();
    final autoPage = ttsSettings.autoPage.value;
    ttsService.speak(
      c,
      originalOnly: ttsSettings.originalOnly.value,
      bilingualAlternate: ttsSettings.bilingualAlternate.value,
      switchIntervalMs: ttsSettings.switchInterval.value,
      onComplete: autoPage ? () => vm.chapterManager.nextPage() : null,
    );
  }

  Future<void> _loadVocabularyWords(Signal<Set<String>> out) async {
    final service = getIt<VocabularyMarkerService>();
    await service.ensureLoaded();
    out.value = service.allWords.toSet();
  }
}
