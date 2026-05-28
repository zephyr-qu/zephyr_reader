library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:zephyr_reader/core/reader/custom_font_service.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/core/reader/tts_service.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/features/reader/application/reader_enums.dart';
import 'package:zephyr_reader/features/reader/application/reader_view_model.dart';
import 'package:zephyr_reader/features/reader/data/vocabulary_marker_service.dart';
import 'package:zephyr_reader/features/reader/domain/models/font_info.dart';
import 'package:zephyr_reader/features/reader/page/reader_page_actions.dart';
import 'package:zephyr_reader/core/utils/haptic.dart';
import 'package:zephyr_reader/src/rust/api/bilingual.dart';

import 'widgets/bookmark_widget.dart';
import 'widgets/reader_catalog_drawer.dart';
import 'widgets/reader_bottom_toolbar.dart';
import 'widgets/reader_content.dart';
import 'widgets/reader_note_sidebar.dart';
import 'widgets/reader_search_bar.dart';
import 'widgets/reader_settings_panel.dart';
import 'widgets/reader_toolbar.dart';
import 'widgets/selection_toolbar.dart';

class ReaderPage extends HookWidget {
  final ReaderViewModel vm;
  final String bookId;
  final int initialChapterId;

  const ReaderPage({
    super.key,
    required this.vm,
    required this.bookId,
    this.initialChapterId = 0,
  });

  @override
  Widget build(BuildContext context) {
    final fontRepo = useMemoized(() => getIt<FontRepository>());
    final ttsService = useMemoized(() => getIt<TtsService>());
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
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
        vm.initialize(bookId, initialChapterId: initialChapterId);
      });
      return vm.dispose;
    }, []);

    // ── Bind VM UI signals ──
    final readerTheme = useSignalValue<ReaderTheme, Signal<ReaderTheme>>(vm.themeMode);
    final showToolbar = useSignalValue<bool, Signal<bool>>(vm.showToolbar);
    final toolbarOpacity = useSignalValue<double, Signal<double>>(vm.toolbarOpacity);
    final showSettings = useSignalValue<bool, Signal<bool>>(vm.showSettings);
    final showCatalog = useSignalValue<bool, Signal<bool>>(vm.showCatalog);
    final showBookmarks = useSignalValue<bool, Signal<bool>>(vm.showBookmarks);
    final showSelection = useSignalValue<bool, Signal<bool>>(vm.showSelectionToolbar);
    final showSearch = useSignalValue<bool, Signal<bool>>(vm.showSearch);
    final bgIndex = useSignalValue<int, Signal<int>>(vm.readerBgColorIndex);
    final brightness = useSignalValue<double, Signal<double>>(vm.brightnessOverlay);
    final currentBookId = useSignalValue<String, Signal<String>>(vm.bookId);
    final chapterIndex = useSignalValue<int, Signal<int>>(vm.chapterIndex);
    final pageIndex = useSignalValue<int, Signal<int>>(vm.pageIndex);
    final totalPages = useSignalValue<int, Signal<int>>(vm.totalPages);
    final currentReadingMode = useSignalValue<ReadingMode, Signal<ReadingMode>>(vm.readingMode);

    // ── Bind reader content signals ──
    final fontSize = useSignalValue<double, Signal<double>>(vm.fontSize);
    final lineHeight = useSignalValue<double, Signal<double>>(vm.lineHeight);
    useSignalValue<FontInfo?, Signal<FontInfo?>>(fontRepo.currentFont);
    final fontFamily = fontRepo.currentFontFamily;
    final chContent = useSignalValue<AsyncState<String>, AsyncSignal<String>>(vm.chapterContent);
    final content = chContent.value ?? '';
    final isLoading = useSignalValue<bool, Signal<bool>>(vm.isLoading);
    final error = useSignalValue<String?, Signal<String?>>(vm.error);
    final bState = useSignalValue<AsyncState<BilingualAlignment?>, AsyncSignal<BilingualAlignment?>>(vm.bilingualAlignment);
    final bilingualAlign = bState.value;
    final isBilingualLoading = bState.isLoading;
    final bilingualError = bState.error?.toString();
    final autoScrollTick = useSignalValue<int, Signal<int>>(vm.autoScrollTick);
    final highlights = useSignalValue<List<Note>, Signal<List<Note>>>(vm.highlights);
    final searchQuery = useSignalValue<String, Signal<String>>(vm.searchQuery);
    final searchCurrentIndex = useSignalValue<int, Signal<int>>(vm.searchCurrentIndex);
    final searchMatchHighlight = searchCurrentIndex > 0;
    final letterSpacing = useSignalValue<double, Signal<double>>(vm.letterSpacing);
    final paragraphSpacing = useSignalValue<double, Signal<double>>(vm.paragraphSpacing);
    final pageMargin = useSignalValue<double, Signal<double>>(vm.pageMargin);
    final writingDirection = useSignalValue<WritingDirection, Signal<WritingDirection>>(vm.writingDirection);
    final pendingJumpCharOffset = useSignalValue<int?, Signal<int?>>(vm.pendingJumpCharOffset);

    final themeMode = readerTheme == ReaderTheme.dark ? ThemeMode.dark : ThemeMode.light;
    final effectiveTotalPages = math.max(1, totalPages);

    void resetHideTimer() {
      autoHideTimer.value?.cancel();
      vm.toolbarOpacity.value = 1.0;
      autoHideTimer.value = Timer(const Duration(seconds: 4), () {
        if (!context.mounted) return;
        if (vm.showToolbar.value && !vm.showSettings.value && !vm.showSearch.value) {
          vm.toolbarOpacity.value = 0.6;
        }
      });
    }

    return PopScope(
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
          themeMode: themeMode,
          onChapterSelected: vm.jumpToChapter,
        ),
        endDrawer: ReaderNoteSidebar(
          bookId: currentBookId,
          bookTitle: vm.currentChapterTitle,
          onNoteTap: (ci, co) => vm.jumpToPosition(ci, co),
        ),
        body: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          color: readerTheme == ReaderTheme.dark
              ? ReaderBgColors.darkBackground
              : ReaderBgColors.presets[bgIndex.clamp(0, ReaderBgColors.presets.length - 1)],
          child: SafeArea(
            child: Stack(
              children: [
                ReaderContent(
                  bookId: currentBookId,
                  chapterId: chapterIndex,
                  pageIndex: pageIndex,
                  totalPages: totalPages,
                  fontSize: fontSize,
                  lineHeight: lineHeight,
                  themeMode: themeMode,
                  readingMode: currentReadingMode,
                  content: content,
                  isLoading: isLoading,
                  error: error,
                  bilingualAlignment: bilingualAlign,
                  isBilingualLoading: isBilingualLoading,
                  bilingualError: bilingualError,
                  onRequestTranslation: () => _showTranslationDialog(context, vm),
                  onPageChanged: vm.loadPage,
                  onRetry: () => vm.loadChapter(chapterIndex, initialCharOffset: vm.currentCharOffset.value, restartSession: false),
                  autoScrollTick: autoScrollTick,
                  highlights: highlights,
                  onSelectionChanged: vm.updateSelection,
                  onSelectionGlobalPosition: (pos) => selectionGlobalPos.value = pos,
                  onHighlightTap: (note) => _showHighlightMenu(context, vm, note),
                  fontFamily: fontFamily,
                  searchQuery: searchQuery,
                  searchMatchHighlight: searchMatchHighlight,
                  letterSpacing: letterSpacing,
                  paragraphSpacing: paragraphSpacing,
                  pageMargin: pageMargin,
                  writingDirection: writingDirection,
                  showVocabularyMark: true,
                  vocabularyWords: vocabWords.value,
                  showSentenceSplit: true,
                  bgIndex: bgIndex,
                  jumpToCharOffset: pendingJumpCharOffset,
                  onPositionChanged: vm.updateCurrentCharOffset,
                  onJumpHandled: vm.consumePendingJumpOffset,
                ),
                if (brightness > 0)
                  IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment.center,
                          radius: 0.6,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: brightness * 0.5),
                            Colors.black.withValues(alpha: brightness),
                          ],
                          stops: const [0.3, 0.7, 1.0],
                        ),
                      ),
                    ),
                  ),
                if (showSearch)
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: ReaderSearchBar(
                      controller: searchController,
                      matchCount: vm.searchMatches.value,
                      currentIndex: vm.searchCurrentIndex.value,
                      onChanged: (q) => _onSearchChanged(q, vm),
                      onNext: () => vm.nextSearchMatch(),
                      onPrev: () => vm.prevSearchMatch(),
                      onClose: () { searchController.clear(); vm.toggleSearch(); },
                    ),
                  ),
                Positioned(
                  top: showSearch ? 56 : 0, left: 0, right: 0,
                  child: RepaintBoundary(
                    child: AnimatedSlide(
                      offset: showToolbar ? Offset.zero : const Offset(0, -1),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutBack,
                      child: AnimatedOpacity(
                        opacity: showToolbar ? toolbarOpacity : 0.0,
                        duration: const Duration(milliseconds: 400),
                        child: AnimatedScale(
                          scale: showToolbar ? 1.0 : 0.92,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutBack,
                          child: ReaderToolbar(
                            title: vm.currentChapterTitle,
                            progress: vm.progressText,
                            themeMode: themeMode,
                            onClose: () { vm.dispose(); context.pop(); },
                            onToggleToolbar: () { vm.toggleToolbar(); resetHideTimer(); },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (!showToolbar && !showSearch && !showCatalog && !showBookmarks)
                  Positioned(
                    bottom: 8, left: 0, right: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${pageIndex + 1} / $effectiveTotalPages',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w400, letterSpacing: 0.8),
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: RepaintBoundary(
                    child: AnimatedSlide(
                      offset: showToolbar ? Offset.zero : const Offset(0, 1),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutBack,
                      child: AnimatedOpacity(
                        opacity: showToolbar ? toolbarOpacity : 0.0,
                        duration: const Duration(milliseconds: 400),
                        child: AnimatedScale(
                          scale: showToolbar ? 1.0 : 0.92,
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutBack,
                          child: ReaderBottomToolbar(
                            currentPageIndex: vm.pageIndex.value,
                            totalPages: vm.totalPages.value,
                            themeMode: themeMode,
                            onShowSettings: () { vm.toggleSettings(); resetHideTimer(); },
                            onTtsToggle: () { _toggleTts(vm, ttsService); resetHideTimer(); },
                            isTtsPlaying: ttsService.isPlaying.value,
                            onShowCatalog: () { scaffoldKey.currentState?.openDrawer(); resetHideTimer(); },
                            onShowNotes: () { scaffoldKey.currentState?.openEndDrawer(); resetHideTimer(); },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (showSettings)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => vm.toggleSettings(),
                      onVerticalDragEnd: (details) {
                        if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
                          vm.toggleSettings();
                        }
                      },
                      child: Container(color: Colors.black.withValues(alpha: 0.3)),
                    ),
                  ),
                AnimatedSlide(
                  offset: showSettings ? Offset.zero : const Offset(0, 1),
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: ReaderSettingsPanel(
                      themeMode: themeMode,
                      readingMode: currentReadingMode,
                      fontSize: vm.fontSize.value,
                      lineHeight: vm.lineHeight.value,
                      letterSpacing: vm.letterSpacing.value,
                      paragraphSpacing: vm.paragraphSpacing.value,
                      pageMargin: vm.pageMargin.value,
                      writingDirection: vm.writingDirection.value,
                      onReadingModeChanged: vm.setReadingMode,
                      onFontSizeChanged: vm.setFontSize,
                      onLineHeightChanged: vm.setLineHeight,
                      onThemeChanged: (tm) => vm.setTheme(tm == ThemeMode.dark ? ReaderTheme.dark : ReaderTheme.light),
                      onLetterSpacingChanged: vm.setLetterSpacing,
                      onParagraphSpacingChanged: vm.setParagraphSpacing,
                      onPageMarginChanged: vm.setPageMargin,
                      onWritingDirectionChanged: vm.setWritingDirection,
                      onClose: vm.toggleSettings,
                      readerBgColorIndex: vm.readerBgColorIndex.value,
                      onReaderBgColorChanged: vm.setReaderBgColor,
                      brightnessValue: vm.brightnessOverlay.value,
                      onBrightnessChanged: vm.setBrightness,
                    ),
                  ),
                ),
                if (showBookmarks)
                  BookmarkWidget(
                    bookmarks: vm.bookmarks.value.value ?? [],
                    themeMode: themeMode,
                    onBookmarkSelected: vm.jumpToBookmark,
                    onAddBookmark: vm.addBookmark,
                    onDeleteBookmark: vm.deleteBookmark,
                    onClose: vm.toggleBookmarks,
                  ),
                if (showSelection && vm.selectedText.value.isNotEmpty)
                  Positioned(
                    top: _toolbarTop(MediaQuery.of(context).size.height, selectionGlobalPos.value),
                    left: 0, right: 0,
                    child: SelectionToolbar(
                      selectedText: vm.selectedText.value,
                      onHighlight: () => vm.saveHighlight(),
                      onAnnotate: () => _showAnnotationDialog(context, vm),
                      onLookup: () => showDictionaryPanel(context, vm.selectedText.value),
                      onAddToVocabulary: () => addToVocabulary(
                        context, vm.selectedText.value,
                        bookId: vm.bookId.value,
                        chapterIndex: vm.chapterIndex.value,
                        charOffset: vm.selectionStart.value,
                      ),
                      onBilingualHighlight: currentReadingMode == ReadingMode.bilingual
                          ? () => onBilingualHighlight(context, vm) : null,
                      onDismiss: () => vm.clearSelection(),
                    ),
                  ),
                if (!showToolbar && !showSelection && !showSearch && !showCatalog && !showBookmarks)
                  Positioned.fill(
                    child: GestureDetector(
                      onTapUp: (details) {
                        final w = context.size?.width ?? 1;
                        final third = w / 3;
                        if (details.localPosition.dx < third) {
                          if (vm.pageIndex.value > 0) { vm.previousPage(); hapticFeedback(HapticType.light); }
                        } else if (details.localPosition.dx < third * 2) {
                          vm.toggleToolbar(); hapticFeedback(HapticType.selection); resetHideTimer();
                        } else {
                          if (vm.pageIndex.value < vm.totalPages.value - 1) { vm.nextPage(); hapticFeedback(HapticType.light); }
                        }
                      },
                    ),
                  ),
              ],
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
    if (ttsService.isPlaying.value) { ttsService.stop(); }
    else { ttsService.speak(c); }
    hapticFeedback(HapticType.medium);
  }

  void _onSearchChanged(String query, ReaderViewModel vm) {
    final c = vm.chapterContent.value.value ?? '';
    if (query.isEmpty || c.isEmpty) {
      vm.updateSearch('', matches: 0, currentIndex: 0, paragraphIndex: -1);
      return;
    }
    final lower = c.toLowerCase();
    final q = query.toLowerCase();
    var count = 0, pos = 0;
    while (true) {
      final idx = lower.indexOf(q, pos);
      if (idx == -1) break;
      count++; pos = idx + q.length;
    }
    vm.updateSearch(query, matches: count, currentIndex: 1, paragraphIndex: -1);
  }

  Future<void> _loadVocabularyWords(Signal<Set<String>> out) async {
    final service = getIt<VocabularyMarkerService>();
    await service.ensureLoaded();
    out.value = <String>{}..addAll(service.cet6)..addAll(service.ielts)..addAll(service.toefl);
  }

  void _showTranslationDialog(BuildContext context, ReaderViewModel vm) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('设置对照译文'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('粘贴或输入当前章节的译文内容：'),
              const SizedBox(height: 12),
              TextField(maxLines: 8, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '在此粘贴译文文本…'), onChanged: (val) => vm.setTranslationContent(val)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('确认')),
        ],
      ),
    );
  }

  void _showAnnotationDialog(BuildContext context, ReaderViewModel vm) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加笔记'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(DesignTokens.spacing(Spacing.sm)),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(DesignTokens.radius(RadiusSize.md)),
                ),
                child: Text(vm.selectedText.value, style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic), maxLines: 3, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(height: 12),
              TextField(controller: controller, maxLines: 5, autofocus: true, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '输入你的笔记内容…')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () { controller.dispose(); Navigator.of(ctx).pop(); }, child: const Text('取消')),
          FilledButton(onPressed: () { vm.saveAnnotation(controller.text); controller.dispose(); Navigator.of(ctx).pop(); }, child: const Text('保存')),
        ],
      ),
    );
  }

  void _showHighlightMenu(BuildContext context, ReaderViewModel vm, Note note) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (note.noteType == NoteType.annotation)
              ListTile(
                leading: const Icon(PhosphorIconsRegular.notePencil),
                title: const Text('编辑笔记'),
                onTap: () { Navigator.pop(ctx); _showEditAnnotationDialog(context, vm, note); },
              ),
            ListTile(
              leading: const Icon(PhosphorIconsRegular.trash, color: Colors.red),
              title: const Text('删除高亮', style: TextStyle(color: Colors.red)),
              onTap: () async { Navigator.pop(ctx); await vm.deleteNote(note.id); },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditAnnotationDialog(BuildContext context, ReaderViewModel vm, Note note) {
    final controller = TextEditingController(text: note.content);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑笔记'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(DesignTokens.spacing(Spacing.sm)),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(DesignTokens.radius(RadiusSize.md)),
              ),
              child: Text(note.selectedText ?? '', style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic), maxLines: 3, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 12),
            TextField(controller: controller, maxLines: 5, autofocus: true, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '输入你的笔记内容…')),
          ],
        ),
        actions: [
          TextButton(onPressed: () { controller.dispose(); Navigator.of(ctx).pop(); }, child: const Text('取消')),
          FilledButton(onPressed: () { final updated = note.copyWith(content: controller.text, updatedAt: DateTime.now()); vm.updateNote(updated); controller.dispose(); Navigator.of(ctx).pop(); }, child: const Text('保存')),
        ],
      ),
    );
  }
}
