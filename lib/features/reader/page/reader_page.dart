library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../core/reader/reader_config.dart';
import '../../../core/theme/theme_constants.dart';
import '../../../di/service_locator.dart';
import '../../../src/rust/api/bilingual_highlight.dart' as bilingual_api;
import '../../../src/rust/api/dictionary.dart' as dict_api;
import '../../../src/rust/domain/types.dart';
import '../../../src/rust/storage/models.dart';
import '../../vocabulary/data/vocabulary_service.dart';
import '../application/reader_view_model.dart';
import '../data/custom_font_service.dart';
import '../data/dictionary_service.dart';
import '../data/tts_service.dart';
import '../data/vocabulary_marker_service.dart';
import 'widgets/bookmark_widget.dart';
import 'widgets/reader_catalog_drawer.dart';
import 'widgets/reader_bottom_toolbar.dart';
import 'widgets/reader_content.dart';
import 'widgets/reader_note_sidebar.dart';
import 'widgets/reader_search_bar.dart';
import 'widgets/reader_settings_panel.dart';
import 'widgets/reader_toolbar.dart';
import 'widgets/selection_toolbar.dart';

class ReaderPage extends StatefulWidget {
  final String bookId;
  final int initialChapterId;

  const ReaderPage({
    super.key,
    required this.bookId,
    this.initialChapterId = 0,
  });

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  final _searchController = TextEditingController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late final ReaderViewModel _vm;
  late final FontRepository _fontRepo;
  final _ttsService = getIt<TtsService>();
  Set<String> _vocabularyWords = const {};
  final _selectionGlobalPos = signal<Offset?>(null);
  void Function()? _toastDisposer;
  Timer? _autoHideTimer;

  @override
  void initState() {
    super.initState();
    _vm = getIt<ReaderViewModel>();
    _fontRepo = getIt<FontRepository>();
    _loadVocabularyWords();
    _toastDisposer = effect(() {
      final msg = _vm.toastMessage.value;
      if (msg.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(msg)));
            _vm.toastMessage.value = '';
          }
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final mediaQuery = MediaQuery.of(context);
      _vm.pageWidth.value =
          mediaQuery.size.width - mediaQuery.padding.horizontal;
      _vm.pageHeight.value =
          mediaQuery.size.height - mediaQuery.padding.vertical;
      _vm.initialize(widget.bookId, initialChapterId: widget.initialChapterId);
    });
  }

  Future<void> _loadVocabularyWords() async {
    final service = getIt<VocabularyMarkerService>();
    await service.ensureLoaded();
    if (!mounted) return;
    final all = <String>{}
      ..addAll(service.cet6)
      ..addAll(service.ielts)
      ..addAll(service.toefl);
    setState(() => _vocabularyWords = all);
  }

  void _resetHideTimer() {
    _autoHideTimer?.cancel();
    _vm.toolbarOpacity.value = 1.0;
    _autoHideTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      if (_vm.showToolbar.value &&
          !_vm.showSettings.value &&
          !_vm.showSearch.value) {
        _vm.toolbarOpacity.value = 0.6;
      }
    });
  }

  void _startAutoHideTimer() {
    _resetHideTimer();
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    _toastDisposer?.call();
    _vm.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final content = _vm.chapterContent.value.value ?? '';
    if (query.isEmpty || content.isEmpty) {
      _vm.updateSearch('', matches: 0, currentIndex: 0, paragraphIndex: -1);
      return;
    }
    final lower = content.toLowerCase();
    final q = query.toLowerCase();
    var count = 0;
    var pos = 0;
    while (true) {
      final idx = lower.indexOf(q, pos);
      if (idx == -1) break;
      count++;
      pos = idx + q.length;
    }
    _vm.updateSearch(
      query,
      matches: count,
      currentIndex: 1,
      paragraphIndex: -1,
    );
  }

  void _nextSearchMatch() {
    _vm.nextSearchMatch();
  }

  void _prevSearchMatch() {
    _vm.prevSearchMatch();
  }

  void _closeSearch() {
    _searchController.clear();
    _vm.toggleSearch();
  }

  static const double _toolbarHeight = 52;

  double _toolbarTop(double screenHeight) {
    final pos = _selectionGlobalPos.value;
    if (pos == null) return 80;
    const gap = 8.0;
    final above = pos.dy - _toolbarHeight - gap;
    if (above > 0) return above;
    final below = pos.dy + gap + 20;
    return below.clamp(0, screenHeight - _toolbarHeight);
  }

  void _toggleTts() {
    final content = _vm.chapterContent.value.value;
    if (content == null || content.isEmpty) return;
    if (_ttsService.isPlaying.value) {
      _ttsService.stop();
    } else {
      _ttsService.speak(content);
    }
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    _vm.pageWidth.value = screenSize.width - padding.horizontal;
    _vm.pageHeight.value = screenSize.height - padding.vertical;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _vm.dispose();
        context.pop();
      },
      child: Watch.builder(
        builder: (context) {
          final themeMode = _vm.themeMode.value;
          final showToolbar = _vm.showToolbar.value;
          final toolbarOpacity = _vm.toolbarOpacity.value;
          final showSettings = _vm.showSettings.value;
          final showCatalog = _vm.showCatalog.value;
          final showBookmarks = _vm.showBookmarks.value;
          final showSelectionToolbar = _vm.showSelectionToolbar.value;
          final showSearch = _vm.showSearch.value;
          final bgIndex = _vm.readerBgColorIndex.value;
          final brightness = _vm.brightnessOverlay.value;
          final bookId = _vm.bookId.value;
          final chapterIndex = _vm.chapterIndex.value;
          final pageIndex = _vm.pageIndex.value;
          final totalPages = _vm.totalPages.value;
          final readingMode = _vm.readingMode.value;

          final effectiveTotalPages = math.max(1, totalPages);

          return Scaffold(
            key: _scaffoldKey,
            drawer: ReaderCatalogDrawer(
              chapters: _vm.chapters.value.value ?? [],
              currentChapterIndex: _vm.chapterIndex.value,
              themeMode: themeMode,
              onChapterSelected: (index) => _vm.jumpToChapter(index),
            ),
            endDrawer: ReaderNoteSidebar(
              bookId: bookId,
              bookTitle: _vm.currentChapterTitle,
              onNoteTap: (chapterIndex, charOffset) {
                _vm.jumpToPosition(chapterIndex, charOffset);
              },
            ),
            body: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              color: _getBackgroundColor(themeMode, bgIndex: bgIndex),
              child: SafeArea(
                child: Stack(
                  children: [
                    Watch.builder(
                      builder: (ctx) {
                        final fontSize = _vm.fontSize.value;
                        final lineHeight = _vm.lineHeight.value;
                        _fontRepo.currentFont.value;
                        final fontFamily = _fontRepo.currentFontFamily;
                        final content = _vm.chapterContent.value.value ?? '';
                        final isLoading = _vm.isLoading.value;
                        final error = _vm.error.value;
                        final bilingualAlignment = _vm.bilingualAlignment.value;
                        final isBilingualLoading = _vm.isBilingualLoading.value;
                        final bilingualError = _vm.bilingualError.value;
                        final autoScrollTick = _vm.autoScrollTick.value;
                        final highlights = _vm.highlights.value;
                        final searchQuery = _vm.searchQuery.value;
                        final searchMatchHighlight =
                            _vm.searchCurrentIndex.value > 0;
                        final letterSpacing = _vm.letterSpacing.value;
                        final paragraphSpacing = _vm.paragraphSpacing.value;
                        final pageMargin = _vm.pageMargin.value;
                        final writingDirection = _vm.writingDirection.value;
                        final pendingJumpCharOffset =
                            _vm.pendingJumpCharOffset.value;

                        return _buildReaderContent(
                          context: ctx,
                          vm: _vm,
                          fontSize: fontSize,
                          lineHeight: lineHeight,
                          themeMode: themeMode,
                          fontFamily: fontFamily,
                          bookId: bookId,
                          chapterIndex: chapterIndex,
                          pageIndex: pageIndex,
                          totalPages: totalPages,
                          readingMode: readingMode,
                          content: content,
                          isLoading: isLoading,
                          error: error,
                          bilingualAlignment: bilingualAlignment,
                          isBilingualLoading: isBilingualLoading,
                          bilingualError: bilingualError,
                          autoScrollTick: autoScrollTick,
                          highlights: highlights,
                          searchQuery: searchQuery,
                          searchMatchHighlight: searchMatchHighlight,
                          letterSpacing: letterSpacing,
                          paragraphSpacing: paragraphSpacing,
                          pageMargin: pageMargin,
                          writingDirection: writingDirection,
                          pendingJumpCharOffset: pendingJumpCharOffset,
                          bgIndex: bgIndex,
                        );
                      },
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
                                Colors.black.withValues(
                                  alpha: brightness * 0.5,
                                ),
                                Colors.black.withValues(alpha: brightness),
                              ],
                              stops: const [0.3, 0.7, 1.0],
                            ),
                          ),
                        ),
                      ),
                    if (showSearch)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: ReaderSearchBar(
                          controller: _searchController,
                          matchCount: _vm.searchMatches.value,
                          currentIndex: _vm.searchCurrentIndex.value,
                          onChanged: _onSearchChanged,
                          onNext: _nextSearchMatch,
                          onPrev: _prevSearchMatch,
                          onClose: _closeSearch,
                        ),
                      ),
                    Positioned(
                      top: showSearch ? 56 : 0,
                      left: 0,
                      right: 0,
                      child: RepaintBoundary(
                        child: AnimatedSlide(
                          offset: showToolbar
                              ? Offset.zero
                              : const Offset(0, -1),
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
                                title: _vm.currentChapterTitle,
                                progress: _vm.progressText,
                                themeMode: themeMode,
                                onClose: () {
                                  _resetHideTimer();
                                  _vm.dispose();
                                  context.pop();
                                },
                                onToggleToolbar: () {
                                  _vm.toggleToolbar();
                                  _resetHideTimer();
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (!showToolbar &&
                        !showSearch &&
                        !showCatalog &&
                        !showBookmarks)
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
                                '${pageIndex + 1} / $effectiveTotalPages',
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
                      child: RepaintBoundary(
                        child: AnimatedSlide(
                          offset: showToolbar
                              ? Offset.zero
                              : const Offset(0, 1),
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
                                currentPageIndex: _vm.pageIndex.value,
                                totalPages: _vm.totalPages.value,
                                themeMode: themeMode,
                                onShowSettings: () {
                                  _vm.toggleSettings();
                                  _resetHideTimer();
                                },
                                onTtsToggle: () {
                                  _toggleTts();
                                  _resetHideTimer();
                                },
                                isTtsPlaying: _ttsService.isPlaying.value,
                                onShowCatalog: () {
                                  _scaffoldKey.currentState?.openDrawer();
                                  _resetHideTimer();
                                },
                                onShowNotes: () {
                                  _scaffoldKey.currentState?.openEndDrawer();
                                  _resetHideTimer();
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (showSettings)
                      Positioned.fill(
                        child: GestureDetector(
                          onTap: () => _vm.toggleSettings(),
                          onVerticalDragEnd: (details) {
                            if (details.primaryVelocity != null &&
                                details.primaryVelocity! > 300) {
                              _vm.toggleSettings();
                            }
                          },
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.3),
                          ),
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
                          readingMode: _vm.readingMode.value,
                          fontSize: _vm.fontSize.value,
                          lineHeight: _vm.lineHeight.value,
                          letterSpacing: _vm.letterSpacing.value,
                          paragraphSpacing: _vm.paragraphSpacing.value,
                          pageMargin: _vm.pageMargin.value,
                          writingDirection: _vm.writingDirection.value,
                          onReadingModeChanged: _vm.setReadingMode,
                          onFontSizeChanged: _vm.setFontSize,
                          onLineHeightChanged: _vm.setLineHeight,
                          onThemeChanged: _vm.setTheme,
                          onLetterSpacingChanged: _vm.setLetterSpacing,
                          onParagraphSpacingChanged: _vm.setParagraphSpacing,
                          onPageMarginChanged: _vm.setPageMargin,
                          onWritingDirectionChanged: _vm.setWritingDirection,
                          onClose: _vm.toggleSettings,
                          readerBgColorIndex: _vm.readerBgColorIndex.value,
                          onReaderBgColorChanged: _vm.setReaderBgColor,
                          brightnessValue: _vm.brightnessOverlay.value,
                          onBrightnessChanged: _vm.setBrightness,

                        ),
                      ),
                    ),
                    if (showBookmarks)
                      BookmarkWidget(
                        bookmarks: _vm.bookmarks.value.value ?? [],
                        themeMode: themeMode,
                        onBookmarkSelected: _vm.jumpToBookmark,
                        onAddBookmark: _vm.addBookmark,
                        onDeleteBookmark: (bookmarkId) {
                          _vm.deleteBookmark(bookmarkId);
                        },
                        onClose: _vm.toggleBookmarks,
                      ),
                    if (showSelectionToolbar &&
                        _vm.selectedText.value.isNotEmpty)
                      Positioned(
                        top: _toolbarTop(screenSize.height),
                        left: 0,
                        right: 0,
                        child: SelectionToolbar(
                            selectedText: _vm.selectedText.value,
                            onHighlight: () => _vm.saveHighlight(),
                            onAnnotate: () =>
                                _showAnnotationDialog(context, _vm),
                            onLookup: () => _showDictionaryPanel(
                              context,
                              _vm.selectedText.value,
                            ),
                            onAddToVocabulary: () => _addToVocabulary(
                              context,
                              _vm.selectedText.value,
                              bookId: _vm.bookId.value,
                              chapterIndex: _vm.chapterIndex.value,
                              charOffset: _vm.selectionStart.value,
                            ),
                            onBilingualHighlight:
                                _vm.readingMode.value == ReadingMode.bilingual
                                ? () => _onBilingualHighlight(context, _vm)
                                : null,
                             onDismiss: () => _vm.clearSelection(),
                          ),
                        ),
                    if (!showToolbar &&
                        !showSelectionToolbar &&
                        !showSearch &&
                        !showCatalog &&
                        !showBookmarks)
                      Positioned.fill(
                        child: GestureDetector(
                          onTapUp: (details) {
                            final width = context.size?.width ?? 1;
                            final third = width / 3;
                            if (details.localPosition.dx < third) {
                              final canPrev = _vm.pageIndex.value > 0;
                              if (canPrev) {
                                _vm.previousPage();
                                HapticFeedback.lightImpact();
                              }
                            } else if (details.localPosition.dx < third * 2) {
                              _vm.toggleToolbar();
                              HapticFeedback.selectionClick();
                              _startAutoHideTimer();
                            } else {
                              final canNext =
                                  _vm.pageIndex.value <
                                  _vm.totalPages.value - 1;
                              if (canNext) {
                                _vm.nextPage();
                                HapticFeedback.lightImpact();
                              }
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReaderContent({
    required BuildContext context,
    required ReaderViewModel vm,
    required double fontSize,
    required double lineHeight,
    required ThemeMode themeMode,
    required String fontFamily,
    required String bookId,
    required int chapterIndex,
    required int pageIndex,
    required int totalPages,
    required ReadingMode readingMode,
    required String content,
    required bool isLoading,
    required String? error,
    required BilingualAlignment? bilingualAlignment,
    required bool isBilingualLoading,
    required String? bilingualError,
    required int autoScrollTick,
    required List<Note> highlights,
    required String searchQuery,
    required bool searchMatchHighlight,
    required double letterSpacing,
    required double paragraphSpacing,
    required double pageMargin,
    required WritingDirection writingDirection,
    required int? pendingJumpCharOffset,
    required int bgIndex,
  }) {
    return Watch.builder(
      builder: (context) => ReaderContent(
        bookId: bookId,
        chapterId: chapterIndex,
        pageIndex: pageIndex,
        totalPages: totalPages,
        fontSize: fontSize,
        lineHeight: lineHeight,
        themeMode: themeMode,
        readingMode: readingMode,
        content: content,
        isLoading: isLoading,
        error: error,
        bilingualAlignment: bilingualAlignment,
        isBilingualLoading: isBilingualLoading,
        bilingualError: bilingualError,
        onRequestTranslation: () => _showTranslationDialog(context, vm),
        onPageChanged: vm.loadPage,
        onRetry: () => vm.loadChapter(
          chapterIndex,
          initialCharOffset: vm.currentCharOffset.value,
          restartSession: false,
        ),
        autoScrollTick: autoScrollTick,
        highlights: highlights,
        onSelectionChanged: (text, start, end) =>
            vm.updateSelection(text, start, end),
        onSelectionGlobalPosition: (pos) => _selectionGlobalPos.value = pos,
        onHighlightTap: (note) => _showHighlightMenu(context, vm, note),
        fontFamily: fontFamily,
        searchQuery: searchQuery,
        searchMatchHighlight: searchMatchHighlight,
        letterSpacing: letterSpacing,
        paragraphSpacing: paragraphSpacing,
        pageMargin: pageMargin,
        writingDirection: writingDirection,
        showVocabularyMark: true,
        vocabularyWords: _vocabularyWords,
        showSentenceSplit: true,
        bgIndex: bgIndex,
        jumpToCharOffset: pendingJumpCharOffset,
        onPositionChanged: vm.updateCurrentCharOffset,
        onJumpHandled: vm.consumePendingJumpOffset,
      ),
    );
  }

  void _showTranslationDialog(BuildContext context, ReaderViewModel vm) {
    showDialog(
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
              TextField(
                maxLines: 8,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '在此粘贴译文文本…',
                ),
                onChanged: (val) => vm.setTranslationContent(val),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  void _showAnnotationDialog(BuildContext context, ReaderViewModel vm) {
    final controller = TextEditingController();
    showDialog(
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
                  borderRadius: BorderRadius.circular(
                    DesignTokens.radius(RadiusSize.md),
                  ),
                ),
                child: Text(
                  vm.selectedText.value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 5,
                autofocus: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '输入你的笔记内容…',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.dispose();
              Navigator.of(ctx).pop();
            },
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              vm.saveAnnotation(controller.text);
              controller.dispose();
              Navigator.of(ctx).pop();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showHighlightMenu(BuildContext context, ReaderViewModel vm, Note note) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (note.noteType == NoteType.annotation)
              ListTile(
                leading: const Icon(PhosphorIconsRegular.notePencil),
                title: const Text('编辑笔记'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditAnnotationDialog(context, vm, note);
                },
              ),
            ListTile(
              leading: const Icon(
                PhosphorIconsRegular.trash,
                color: Colors.red,
              ),
              title: const Text('删除高亮', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(ctx);
                await vm.deleteNote(note.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditAnnotationDialog(
    BuildContext context,
    ReaderViewModel vm,
    Note note,
  ) {
    final controller = TextEditingController(text: note.content);
    showDialog(
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
                borderRadius: BorderRadius.circular(
                  DesignTokens.radius(RadiusSize.md),
                ),
              ),
              child: Text(
                note.selectedText ?? '',
                style: const TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 5,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '输入你的笔记内容…',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.dispose();
              Navigator.of(ctx).pop();
            },
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final updated = note.copyWith(
                content: controller.text,
                updatedAt: DateTime.now(),
              );
              vm.updateNote(updated);
              controller.dispose();
              Navigator.of(ctx).pop();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Color _getBackgroundColor(ThemeMode themeMode, {int bgIndex = 0}) {
    switch (themeMode) {
      case ThemeMode.dark:
        return ReaderBgColors.darkBackground;
      case ThemeMode.light:
      default:
        return ReaderBgColors.presets[bgIndex.clamp(
          0,
          ReaderBgColors.presets.length - 1,
        )];
    }
  }
}

void _showDictionaryPanel(BuildContext context, String text) async {
  if (text.trim().isEmpty) return;
  final dict = getIt<DictionaryService>();
  List<dict_api.DictEntry> entries = [];
  List<String> segments = [];
  bool loading = true;
  String? error;

  try {
    final results = await Future.wait([
      dict.lookup(text.trim()),
      dict.segment(text.trim()),
    ]);
    entries = results[0] as List<dict_api.DictEntry>;
    segments = results[1] as List<String>;
    await HapticFeedback.lightImpact();
  } catch (e) {
    error = e.toString();
  }
  loading = false;

  if (!context.mounted) return;

  // ignore: unawaited_futures
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.25,
      maxChildSize: 0.75,
      expand: false,
      builder: (ctx, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: DesignTokens.spacing(Spacing.md)),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (entries.isNotEmpty) ...[
                SizedBox(height: DesignTokens.spacing(Spacing.xs)),
                Text(
                  entries.first.pinyin,
                  style: const TextStyle(fontSize: 15, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                ...entries.first.definitions
                    .split('/')
                    .where((d) => d.isNotEmpty)
                    .map(
                      (d) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '• ',
                              style: TextStyle(color: Colors.grey),
                            ),
                            Expanded(
                              child: Text(
                                d,
                                style: const TextStyle(fontSize: 15),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ] else if (loading) ...[
                SizedBox(height: DesignTokens.spacing(Spacing.lg)),
                const Center(child: CircularProgressIndicator()),
              ] else ...[
                SizedBox(height: DesignTokens.spacing(Spacing.lg)),
                Text(
                  error ?? '未找到释义',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
              if (segments.length > 1) ...[
                SizedBox(height: DesignTokens.spacing(Spacing.lg)),
                const Text(
                  '分词：',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: segments
                      .map(
                        (s) => ActionChip(
                          label: Text(s, style: const TextStyle(fontSize: 13)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showDictionaryPanel(context, s);
                          },
                        ),
                      )
                      .toList(),
                ),
              ],
              if (entries.isNotEmpty) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _addToVocabulary(context, text);
                  },
                  icon: const Icon(PhosphorIconsRegular.listPlus, size: 18),
                  label: const Text('加入生词本'),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}

Future<void> _addToVocabulary(
  BuildContext context,
  String word, {
  String? bookId,
  int? chapterIndex,
  int? charOffset,
}) async {
  final trimmed = word.trim();
  if (trimmed.isEmpty) return;

  final vocabularyService = getIt<VocabularyService>();
  final dictionaryService = getIt<DictionaryService>();

  try {
    final entries = await dictionaryService.lookup(trimmed);
    final entry = entries.isNotEmpty ? entries.first : null;
    final translation = entry == null
        ? trimmed
        : entry.definitions
              .split('/')
              .where((d) => d.trim().isNotEmpty)
              .join('；');
    await vocabularyService.addWord(
      word: trimmed,
      pinyin: entry?.pinyin ?? '',
      translation: translation.isEmpty ? trimmed : translation,
      bookId: bookId,
      chapterIndex: chapterIndex,
      charOffset: charOffset,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已加入生词本：$trimmed'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('加入生词本失败：$e'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

Future<void> _onBilingualHighlight(
  BuildContext context,
  ReaderViewModel vm,
) async {
  final text = vm.selectedText.value;
  if (text.isEmpty) return;

  final alignment = vm.bilingualAlignment.value;
  if (alignment == null || alignment.segments.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('没有对照译文，无法创建双语高亮'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return;
  }

  final startOffset = vm.selectionStart.value;
  final length = vm.selectionEnd.value - vm.selectionStart.value;

  int segmentIndex = -1;
  String sourceLanguage = 'zh';
  String targetLanguage = 'en';
  int targetOffset = 0;

  var cnAcc = 0;
  var enAcc = 0;
  for (int i = 0; i < alignment.segments.length; i++) {
    final seg = alignment.segments[i];
    final cnEnd = cnAcc + seg.chinese.length;
    final enEnd = enAcc + seg.english.length;

    if (startOffset >= cnAcc && startOffset < cnEnd) {
      segmentIndex = i;
      sourceLanguage = 'zh';
      targetLanguage = 'en';
      targetOffset = enAcc;
      break;
    }
    if (startOffset >= enAcc && startOffset < enEnd) {
      segmentIndex = i;
      sourceLanguage = 'en';
      targetLanguage = 'zh';
      targetOffset = cnAcc;
      break;
    }

    cnAcc += seg.chinese.length;
    enAcc += seg.english.length;
  }

  if (segmentIndex == -1) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('未找到对应的段落'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return;
  }

  final seg = alignment.segments[segmentIndex];
  final targetText = targetLanguage == 'zh' ? seg.chinese : seg.english;

  try {
    await bilingual_api.createBilingualHighlightPair(
      sourceBookId: vm.bookId.value,
      sourceChapterIndex: vm.chapterIndex.value,
      sourceCharOffset: startOffset,
      sourceLength: length,
      sourceSelectedText: text,
      sourceLanguage: sourceLanguage,
      targetBookId: vm.bookId.value,
      targetChapterIndex: vm.chapterIndex.value,
      targetCharOffset: targetOffset,
      targetLength: targetText.length,
      targetSelectedText: targetText,
      targetLanguage: targetLanguage,
      highlightColor: 0xFFE91E63,
    );

    vm.clearSelection();
    await vm.loadHighlights();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('双语高亮已创建'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建失败：$e'), behavior: SnackBarBehavior.floating),
      );
    }
  }
}
