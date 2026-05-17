library;

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../../../di/service_locator.dart';

import '../../../src/rust/storage/models.dart';
import '../../../src/rust/api/bilingual_highlight.dart' as bilingual_api;
import '../../../src/rust/api/dictionary.dart' as dict_api;
import '../data/custom_font_service.dart';
import '../data/dictionary_service.dart';
import '../application/reader_view_model.dart';
import 'widgets/reader_content.dart';
import 'widgets/reader_search_bar.dart';
import 'widgets/reader_toolbar.dart';
import 'widgets/reader_bottom_toolbar.dart';
import 'widgets/chapter_list_widget.dart';
import 'widgets/reader_settings_panel.dart';
import 'widgets/bookmark_widget.dart';
import 'widgets/selection_toolbar.dart';
import 'widgets/reader_note_sidebar.dart';
import '../data/tts_service.dart';
import '../data/vocabulary_marker_service.dart';

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
  final _ttsService = getIt<TtsService>();
  Set<String> _vocabularyWords = const {};

  @override
  void initState() {
    super.initState();
    _loadVocabularyWords();
  }

  Future<void> _loadVocabularyWords() async {
    final service = getIt<VocabularyMarkerService>();
    await service.ensureLoaded();
    final all = <String>{}
      ..addAll(service.cet6)
      ..addAll(service.ielts)
      ..addAll(service.toefl);
    setState(() => _vocabularyWords = all);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final vm = GetIt.I.get<ReaderViewModel>();
    final content = vm.chapterContent.value.value ?? '';
    if (query.isEmpty || content.isEmpty) {
      vm.updateSearch('', matches: 0, currentIndex: 0, paragraphIndex: -1);
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
    vm.updateSearch(query, matches: count, currentIndex: 1, paragraphIndex: -1);
  }

  void _nextSearchMatch() {
    final vm = GetIt.I.get<ReaderViewModel>();
    vm.nextSearchMatch();
  }

  void _prevSearchMatch() {
    final vm = GetIt.I.get<ReaderViewModel>();
    vm.prevSearchMatch();
  }

  void _closeSearch() {
    _searchController.clear();
    final vm = GetIt.I.get<ReaderViewModel>();
    vm.toggleSearch();
  }

  void _toggleTts() {
    final vm = GetIt.I.get<ReaderViewModel>();
    final content = vm.chapterContent.value.value;
    if (content == null || content.isEmpty) return;
    if (_ttsService.isPlaying) {
      _ttsService.stop();
    } else {
      _ttsService.speak(content);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final vm = GetIt.I.get<ReaderViewModel>();
    final fontRepo = GetIt.I.get<FontRepository>();

    final screenSize = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    vm.pageWidth.value = screenSize.width - padding.horizontal;
    vm.pageHeight.value = screenSize.height - padding.vertical;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      vm.initialize(widget.bookId, initialChapterId: widget.initialChapterId);
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        vm.dispose();
        context.pop();
      },
      child: Watch.builder(
        builder: (context) {
          final themeMode = vm.themeMode.value;
          final showToolbar = vm.showToolbar.value;
          final showCatalog = vm.showCatalog.value;
          final showSettings = vm.showSettings.value;
          final showBookmarks = vm.showBookmarks.value;
          final showSelectionToolbar = vm.showSelectionToolbar.value;
          final showSearch = vm.showSearch.value;
          fontRepo.currentFont.value;
          final fontFamily = fontRepo.currentFontFamily;

          return Scaffold(
            key: _scaffoldKey,
            endDrawer: ReaderNoteSidebar(
              bookId: vm.bookId.value,
              bookTitle: vm.currentChapterTitle,
              onNoteTap: (chapterIndex, charOffset) {
                vm.loadChapter(chapterIndex);
              },
            ),
            body: Container(
              color: _getBackgroundColor(themeMode, bgIndex: vm.readerBgColorIndex.value),
              child: SafeArea(
                child: Stack(
                  children: [
                    ReaderContent(
                        bookId: vm.bookId.value,
                        chapterId: vm.chapterIndex.value,
                        pageIndex: vm.pageIndex.value,
                        totalPages: vm.totalPages.value,
                        fontSize: vm.fontSize.value,
                        lineHeight: vm.lineHeight.value,
                        themeMode: themeMode,
                        readingMode: vm.readingMode.value,
                        content: vm.chapterContent.value.value ?? '',
                        isLoading: vm.isLoading.value,
                        error: vm.error.value,
                        bilingualAlignment: vm.bilingualAlignment.value,
                        isBilingualLoading: vm.isBilingualLoading.value,
                        bilingualError: vm.bilingualError.value,
                        onRequestTranslation: () => _showTranslationDialog(context, vm),
                        onPageChanged: vm.loadPage,
                        onRetry: () => vm.loadChapter(vm.chapterIndex.value),
                        autoScrollTick: vm.autoScrollTick.value,
                        highlights: vm.highlights.value,
                        onSelectionChanged: (text, start, end) => vm.updateSelection(text, start, end),
                        onHighlightTap: (note) => _showHighlightMenu(context, vm, note),
                        fontFamily: fontFamily,
                        searchQuery: vm.searchQuery.value,
                        searchMatchHighlight: vm.searchCurrentIndex.value > 0,
                        letterSpacing: vm.letterSpacing.value,
                        paragraphSpacing: vm.paragraphSpacing.value,
                        pageMargin: vm.pageMargin.value,
                        writingDirection: vm.writingDirection.value,
                        showVocabularyMark: true,
                        vocabularyWords: _vocabularyWords,
                        showSentenceSplit: true,
                      ),
                    if (vm.brightnessOverlay.value > 0)
                      IgnorePointer(
                        child: Container(color: Colors.black.withValues(alpha: vm.brightnessOverlay.value)),
                      ),
                    if (showSearch)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: ReaderSearchBar(
                          controller: _searchController,
                          matchCount: vm.searchMatches.value,
                          currentIndex: vm.searchCurrentIndex.value,
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
                      child: AnimatedOpacity(
                        opacity: showToolbar ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: ReaderToolbar(
                          title: vm.currentChapterTitle,
                          progress: vm.progressText,
                          themeMode: themeMode,
                          hasBookmark: vm.hasBookmarkAtCurrentPosition,
                          bookId: widget.bookId,
                          onClose: () {
                            vm.dispose();
                            context.pop();
                          },
                          onToggleToolbar: vm.toggleToolbar,
                          onShowCatalog: vm.toggleCatalog,
                          onShowBookmarks: vm.toggleBookmarks,
                          onToggleBookmark: () => vm.toggleBookmarkAtCurrentPosition(),
                          onShowSearch: () {
                            _searchController.clear();
                            vm.toggleSearch();
                            _onSearchChanged('');
                          },
                          onShowNotes: () => _scaffoldKey.currentState?.openEndDrawer(),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: AnimatedOpacity(
                        opacity: showToolbar ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: ReaderBottomToolbar(
                          currentChapterId: vm.chapterIndex.value,
                          currentPageIndex: vm.pageIndex.value,
                          totalPages: vm.totalPages.value,
                          themeMode: themeMode,
                          onPreviousChapter: vm.previousChapter,
                          onNextChapter: vm.nextChapter,
                          onPreviousPage: vm.previousPage,
                          onNextPage: vm.nextPage,
                          onShowSettings: vm.toggleSettings,
                          onTtsToggle: _toggleTts,
                          isTtsPlaying: _ttsService.isPlaying,
                        ),
                      ),
                    ),
                    if (showCatalog)
                      ChapterListWidget(
                        chapters: vm.chapters.value.value ?? [],
                        currentChapterIndex: vm.chapterIndex.value,
                        themeMode: themeMode,
                        onChapterSelected: (index) => vm.jumpToChapter(index),
                        onClose: vm.toggleCatalog,
                      ),
                    if (showSettings)
                      ReaderSettingsPanel(
                        themeMode: themeMode,
                        readingMode: vm.readingMode.value,
                        fontSize: vm.fontSize.value,
                        lineHeight: vm.lineHeight.value,
                        letterSpacing: vm.letterSpacing.value,
                        paragraphSpacing: vm.paragraphSpacing.value,
                        pageMargin: vm.pageMargin.value,
                        writingDirection: vm.writingDirection.value,
                        onReadingModeChanged: vm.setReadingMode,
                        onFontSizeChanged: vm.setFontSize,
                        onLineHeightChanged: vm.setLineHeight,
                        onThemeChanged: vm.setTheme,
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
                    if (showBookmarks)
                      BookmarkWidget(
                        bookmarks: vm.bookmarks.value.value ?? [],
                        themeMode: themeMode,
                        onBookmarkSelected: vm.jumpToBookmark,
                        onAddBookmark: vm.addBookmark,
                        onDeleteBookmark: (bookmarkId) {
                          vm.deleteBookmark(bookmarkId);
                        },
                        onClose: vm.toggleBookmarks,
                      ),
                    if (showSelectionToolbar && vm.selectedText.value.isNotEmpty)
                      Positioned(
                        top: 80,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: SelectionToolbar(
                            selectedText: vm.selectedText.value,
                            onHighlight: () => vm.saveHighlight(),
                            onAnnotate: () => _showAnnotationDialog(context, vm),
                            onLookup: () => _showDictionaryPanel(context, vm.selectedText.value),
                            onAddToVocabulary: () => _addToVocabulary(context, vm.selectedText.value),
                            onBilingualHighlight: vm.readingMode.value == ReadingMode.bilingual
                                ? () => _onBilingualHighlight(context, vm)
                                : null,
                            onDismiss: () => vm.clearSelection(),
                          ),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  vm.selectedText.value,
                  style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
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
                leading: const Icon(Icons.edit),
                title: const Text('编辑笔记'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditAnnotationDialog(context, vm, note);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
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

  void _showEditAnnotationDialog(BuildContext context, ReaderViewModel vm, Note note) {
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                note.selectedText ?? '',
                style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
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
        return const Color(0xFF0A0A0A);
      case ThemeMode.light:
      default:
        return ReaderBgColors.presets[bgIndex.clamp(0, ReaderBgColors.presets.length - 1)];
    }
  }
}

class ReaderBgColors {
  static const presets = [
    Color(0xFFFAFAFA), // 默认白
    Color(0xFFF5F0E8), // 羊皮纸
    Color(0xFFFFF8E7), // 奶油
    Color(0xFFC7EDCC), // 护眼绿
    Color(0xFFF0F0F0), // 灰色
  ];
}

void _showDictionaryPanel(BuildContext context, String text) async {
  if (text.trim().isEmpty) return;
  final dict = GetIt.I.get<DictionaryService>();
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
                child: Container(width: 32, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300], borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(text, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              if (entries.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(entries.first.pinyin,
                  style: const TextStyle(fontSize: 15, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                ...entries.first.definitions.split('/').where((d) => d.isNotEmpty).map((d) =>
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('• ', style: TextStyle(color: Colors.grey)),
                      Expanded(child: Text(d, style: const TextStyle(fontSize: 15))),
                    ]),
                  ),
                ),
              ] else if (loading) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
              ] else ...[
                const SizedBox(height: 24),
                Text(error ?? '未找到释义', style: const TextStyle(color: Colors.grey)),
              ],
              if (segments.length > 1) ...[
                const SizedBox(height: 24),
                const Text('分词：', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: segments.map((s) => ActionChip(
                    label: Text(s, style: const TextStyle(fontSize: 13)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showDictionaryPanel(context, s);
                    },
                  )).toList(),
                ),
              ],
              if (entries.isNotEmpty) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _addToVocabulary(context, text);
                  },
                  icon: const Icon(Icons.playlist_add, size: 18),
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

void _addToVocabulary(BuildContext context, String word) {
  if (word.trim().isEmpty) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('已加入生词本：$word'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}

Future<void> _onBilingualHighlight(BuildContext context, ReaderViewModel vm) async {
  final text = vm.selectedText.value;
  if (text.isEmpty) return;

  final alignment = vm.bilingualAlignment.value;
  if (alignment == null || alignment.segments.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有对照译文，无法创建双语高亮'), behavior: SnackBarBehavior.floating),
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
        const SnackBar(content: Text('未找到对应的段落'), behavior: SnackBarBehavior.floating),
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
        const SnackBar(content: Text('双语高亮已创建'), behavior: SnackBarBehavior.floating),
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
