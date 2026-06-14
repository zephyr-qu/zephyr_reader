import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:zephyr_reader/features/reader/page/renderer/reader_render_config.dart';
import 'package:zephyr_reader/features/reader/page/renderer/scroll_mode_renderer.dart';
import 'package:zephyr_reader/features/reader/page/renderer/bilingual_renderer.dart';
import 'package:zephyr_reader/features/reader/page/renderer/paginated_renderer.dart';
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
import 'package:zephyr_reader/features/reader/page/settings/reader_settings_overlay.dart';
import 'package:zephyr_reader/features/reader/page/toolbar/animated_toolbar_panel.dart';
import 'package:zephyr_reader/features/reader/page/toolbar/reader_toolbar.dart';
import 'package:zephyr_reader/src/rust/api/bilingual.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/features/reader/page/touch/selection_toolbar.dart';
import 'package:zephyr_reader/features/reader/page/touch/tap_zone.dart';
import 'package:zephyr_reader/features/reader/page/ui/battery_indicator.dart';
import 'package:zephyr_reader/features/reader/page/ui/brightness_mask.dart';
import 'package:zephyr_reader/features/reader/page/widgets/reader_content.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
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
    final ReaderTheme b_readerTheme = useSignalValue(vm.config.theme.signal);
    final int b_bgIndex = useSignalValue(vm.config.readerBgColorIndex.signal);
    final double b_brightness = useSignalValue(vm.config.brightnessOverlay);
    final String b_currentBookId = useSignalValue(vm.state.bookId);
    final int b_chapterIndex = useSignalValue(vm.state.chapterIndex);
    final int b_pageIndex = useSignalValue(vm.chapterManager.pageIndex);
    final int b_totalPages = useSignalValue(vm.chapterManager.totalPages);
    final ReadingMode b_currentReadingMode = useSignalValue(vm.state.readingMode);
    final double b_fontSize = useSignalValue(vm.config.fontSizeDouble);
    final double b_lineHeight = useSignalValue(vm.config.lineHeight.signal);
    final AsyncState<String> chContent = useSignalValue(vm.state.chapterContent);
    final String b_content = chContent.value ?? '';
    final bool b_isLoading = useSignalValue(vm.chapterManager.isLoading);
    final String? b_error = useSignalValue(vm.chapterManager.error);
    final AsyncState<BilingualAlignment?> bState = useSignalValue(vm.translation.bilingualAlignment);
    final BilingualAlignment? b_bilingualAlign = bState.value;
    final bool b_isBilingualLoading = bState.isLoading;
    final int b_autoScrollTick = useSignalValue(vm.chapterManager.autoScrollTick);
    final AsyncState<List<Note>> highlightsState = useSignalValue(vm.annotations.highlights);
    final List<Note> b_highlights = highlightsState.value ?? [];
    final double b_letterSpacing = useSignalValue(vm.config.letterSpacing.signal);
    final double b_paragraphSpacing = useSignalValue(vm.config.paragraphSpacing.signal);
    final double b_pageMargin = useSignalValue(vm.config.padding.signal);
    final WritingDirection b_writingDirection = useSignalValue(vm.config.writingDirection);
    final int? b_pendingJumpCharOffset = useSignalValue(vm.state.pendingJumpCharOffset);
    final String b_progressText = useSignalValue(vm.chapterManager.progressText);
    final String b_currentChapterTitle = useSignalValue(vm.chapterManager.currentChapterTitle);
    final bool b_baselineAlign = useSignalValue(vm.config.baselineAlign.signal);
    final TextAlign b_textAlign = useSignalValue(vm.config.textAlign.signal);
    final String b_selectedText = useSignalValue(vm.annotations.selectedText);
    final int b_selectionStart = useSignalValue(vm.annotations.selectionStart);
    final dynamic chaptersState = useSignalValue(vm.chapterManager.chapters);
    final int b_numChapters = (chaptersState.value as List?)?.length ?? 0;
    final themeMode = switch (b_readerTheme) {
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
    final readerExt = ReaderThemeExtension.resolve(b_readerTheme);
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
                backgroundColor: ReaderContent.getBackgroundColor(themeMode, b_bgIndex),
                fontSize: b_fontSize,
                lineHeight: b_lineHeight,
                fontFamily: fontFamily,
                letterSpacing: b_letterSpacing,
                paragraphSpacing: b_paragraphSpacing,
                pageMargin: b_pageMargin,
                showVocabularyMark: true,
                vocabularyWords: vocabWords.value,
                baselineAlign: b_baselineAlign,
                textAlign: b_textAlign,
              );
              final onHighlightTap = (Note note) => showModalBottomSheet<void>(
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
                bookId: b_currentBookId,
                chapterId: b_chapterIndex,
                pageIndex: b_pageIndex,
                totalPages: b_totalPages,
                renderConfig: renderConfig,
                readingMode: b_currentReadingMode,
                content: b_content,
                isLoading: b_isLoading,
                error: b_error,
                hasNextChapter:
                    b_chapterIndex < b_numChapters - 1,
                scrollBuilder: (_, sc) => ScrollModeRenderer(
                  config: renderConfig,
                  scrollController: sc,
                  repo: readRepo,
                  bookId: b_currentBookId,
                  chapterId: b_chapterIndex,
                  content: b_content,
                  highlights: b_highlights,
                  onHighlightTap: onHighlightTap,
                  onSelectionChanged: vm.annotations.updateSelection,
                  onSelectionGlobalPosition: (pos) => selectionGlobalPos.value = pos,
                  writingDirection: b_writingDirection,
                  showSentenceSplit: true,
                ),
                bilingualBuilder: (_, sc, pairs) => BilingualModeRenderer(
                  config: renderConfig,
                  scrollController: sc,
                  bilingualPairs: pairs,
                  isBilingualLoading: b_isBilingualLoading,
                  bilingualAlignment: b_bilingualAlign,
                  highlights: b_highlights,
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
                  onRetryTranslation: () => unawaited(vm.translation.translateChapter()),
                  onHighlightTap: onHighlightTap,
                  onSelectionChanged: vm.annotations.updateSelection,
                  onSelectionGlobalPosition: (pos) => selectionGlobalPos.value = pos,
                  writingDirection: b_writingDirection,
                ),
                paginatedBuilder: (_, pc) => PaginatedModeRenderer(
                  config: renderConfig,
                  pageController: pc,
                  repo: readRepo,
                  bookId: b_currentBookId,
                  chapterId: b_chapterIndex,
                  pageIndex: b_pageIndex,
                  content: b_content,
                  highlights: b_highlights,
                  readingMode: b_currentReadingMode,
                  onHighlightTap: onHighlightTap,
                  onSelectionChanged: vm.annotations.updateSelection,
                  onSelectionGlobalPosition: (pos) => selectionGlobalPos.value = pos,
                  onPageChanged: vm.loadPage,
                  onPositionChanged: vm.chapterManager.updateCurrentCharOffset,
                  writingDirection: b_writingDirection,
                ),
                onPageChanged: vm.loadPage,
                onRetry: () => vm.loadChapter(
                  b_chapterIndex,
                  initialCharOffset: vm.state.currentCharOffset.value,
                  restartSession: false,
                ),
                autoScrollTick: b_autoScrollTick,
                highlights: b_highlights,
                onSelectionChanged: vm.annotations.updateSelection,
                onSelectionGlobalPosition: (pos) => selectionGlobalPos.value = pos,
                writingDirection: b_writingDirection,
                jumpToCharOffset: b_pendingJumpCharOffset,
                onPositionChanged: vm.chapterManager.updateCurrentCharOffset,
                onJumpHandled: vm.chapterManager.consumePendingJumpOffset,
                onReachEnd: () => unawaited(vm.chapterManager.nextChapter()),
              );
            },
          ),
        ),
        BrightnessMask(
          brightness: b_brightness,
          readingMode: b_currentReadingMode,
          onDoubleTap: cycleBrightness,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: BatteryIndicator(progressText: b_progressText),
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
            title: b_currentChapterTitle,
            progress: b_progressText,
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
                queryParameters: {'bookId': b_currentBookId},
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
                    readingMode: b_currentReadingMode,
                    isTtsPlaying: ttsService.isPlaying.value,
                    isTtsPaused: ttsService.isPaused.value,
                    onReadingModeChanged: vm.setReadingMode,
                    onFontSizeChanged: vm.setFontSize,
                    onLineHeightChanged: vm.setLineHeight,
                    onLetterSpacingChanged: (v) => vm.setLetterSpacing(v),
                    onParagraphSpacingChanged: (v) => vm.setParagraphSpacing(v),
                    onPageMarginChanged: (m) => vm.setPageMargin(m),
                    onTtsToggle: () => _toggleTts(vm, ttsService),
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
          selectedText: b_selectedText,
          onHighlight: () => vm.saveHighlight(l10n),
          onAnnotate: () => showDialog<void>(
            context: context,
            builder: (_) => ReaderAnnotationDialog(
              selectedText: b_selectedText,
              onSave: (text) => vm.saveAnnotation(text, l10n),
            ),
          ),
          onLookup: () =>
              showDictionaryPanel(context, vm, b_selectedText),
          onAddToVocabulary: () => addToVocabulary(
            context,
            vm,
            b_selectedText,
            bookId: vm.state.bookId.value,
            chapterIndex: vm.state.chapterIndex.value,
            charOffset: b_selectionStart,
          ),
          onBilingualHighlight: b_currentReadingMode == ReadingMode.bilingual
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
            currentChapterIndex: b_chapterIndex,
            onChapterSelected: (idx) {
              vm.chapterManager.jumpToChapter(idx);
            },
            bookmarks: vm.bookmarks.bookmarks.value.value ?? [],
            onBookmarkSelected: (bm) => vm.jumpToBookmark(bm),
            onAddBookmark: () => vm.toggleBookmarkAtCurrentPosition(),
            onDeleteBookmark: (id) => vm.bookmarks.deleteBookmark(id),
            themeMode: themeMode,
            bookId: b_currentBookId,
          ),
          endDrawer: ReaderNoteSidebar(
            bookId: b_currentBookId,
            bookTitle: b_currentChapterTitle,
            vm: vm,
            onNoteTap: (ci, co) => vm.chapterManager.jumpToPosition(ci, co),
          ),
          body: AnimatedContainer(
            duration: AnimTokens.slow,
            curve: Curves.easeInOut,
            color: b_readerTheme == ReaderTheme.dark
                ? ReaderBgColors.darkBackground
                : ReaderBgColors.presets[b_bgIndex.clamp(
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
                        b_currentReadingMode != ReadingMode.pageTurn)
                      TapZone(
                        tapLayout: tapLayout,
                        pageIndex: b_pageIndex,
                        totalPages: b_totalPages,
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
