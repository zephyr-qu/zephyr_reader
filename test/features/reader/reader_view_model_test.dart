library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/features/reader/application/reader_enums.dart';
import 'package:zephyr_reader/features/reader/application/reader_view_model.dart';
import 'package:zephyr_reader/features/reader/data/note_repository.dart';
import 'package:zephyr_reader/features/reader/data/repositories/rust_reader_repository.dart';
import 'package:zephyr_reader/features/statistics/application/reading_stats_service.dart';
import 'package:zephyr_reader/features/statistics/domain/repositories/statistics_repository.dart';
import 'package:zephyr_reader/src/rust/domain/types.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

import '../../helpers/fixtures.dart';

class _MockReaderConfig implements ReaderConfig {
  @override
  final theme = signal<ReaderTheme>(ReaderTheme.light);

  @override
  final fontSize = signal<ReaderFontSize>(ReaderFontSize.medium);

  @override
  final lineHeight = signal<double>(1.6);

  @override
  final paragraphSpacing = signal<double>(16.0);

  @override
  final padding = signal<double>(16.0);

  @override
  final autoScroll = signal<bool>(false);

  @override
  final autoScrollSpeed = signal<int>(30);

  @override
  late final SharedPreferences prefs;

  @override
  Future<void> setTheme(ReaderTheme newTheme) async {
    theme.value = newTheme;
  }

  @override
  Future<void> setFontSize(ReaderFontSize newSize) async {
    fontSize.value = newSize;
  }

  @override
  Future<void> setLineHeight(double value) async {
    lineHeight.value = value;
  }

  @override
  Future<void> setParagraphSpacing(double value) async {
    paragraphSpacing.value = value;
  }

  @override
  Future<void> setPadding(double value) async {
    padding.value = value;
  }

  @override
  Future<void> setAutoScroll(bool value) async {
    autoScroll.value = value;
  }

  @override
  Future<void> setAutoScrollSpeed(int value) async {
    autoScrollSpeed.value = value;
  }

  @override
  Future<void> resetToDefault() async {
    await setTheme(ReaderTheme.light);
    await setFontSize(ReaderFontSize.medium);
    await setLineHeight(1.6);
    await setParagraphSpacing(16.0);
    await setPadding(16.0);
    await setAutoScroll(false);
    await setAutoScrollSpeed(30);
  }

  @override
  final readerBgColorIndex = signal<int>(0);

  @override
  Future<void> setReaderBgColorIndex(int index) async {
    readerBgColorIndex.value = index;
  }
}

class _MockReaderRepository implements ReaderRepository {
  final List<Chapter> chapters;
  final String chapterContent;
  List<Bookmark> bookmarks;
  final ReadingProgressData? progress;
  final List<PageInfo> pages;

  _MockReaderRepository({
    this.chapters = const [],
    this.chapterContent = '',
    List<Bookmark> bookmarks = const [],
    this.progress,
    this.pages = const [],
  }) : bookmarks = List.from(bookmarks);

  @override
  Future<List<Chapter>> getChapters(int bookId) async => chapters;

  @override
  Future<Chapter?> getChapter(int bookId, int chapterIndex) async {
    return chapters.where((c) => c.chapterIndex == chapterIndex).firstOrNull;
  }

  @override
  Future<String> loadChapterContent(
    String bookId,
    int chapterId, {
    String? contentFilePath,
  }) async => chapterContent;

  @override
  Future<List<PageInfo>> calculatePages({
    required String bookId,
    required int chapterId,
    required double fontSize,
    required double lineHeight,
    required double width,
    required double height,
    required double padding,
  }) async => pages;

  @override
  Future<List<Bookmark>> getBookmarks(String bookId) async => bookmarks;

  @override
  Future<int> addBookmark(String bookId, int chapterId, int position) async =>
      1;

  @override
  Future<bool> deleteBookmark(String bookmarkId) async => true;

  @override
  void gcChapterCache(String bookId, int currentChapter, {int keepRange = 5}) {}

  @override
  Future<void> preloadChapter(String bookId, int chapterId) async {}

  @override
  Future<void> updateReadingProgress({
    required String bookId,
    required int chapterId,
    required int charOffset,
    required int pageIndex,
    required int totalPages,
    int readingTimeSeconds = 0,
  }) async {}

  @override
  Future<ReadingProgressData?> loadReadingProgress(String bookId) async =>
      progress;

  @override
  List<PageInfo>? getCachedPages(String bookId, int chapterId) => pages;

  @override
  Future<EpubMetadata?> getEpubMetadata(String filePath) async => null;

  @override
  Future<String?> getChapterContent(String contentFile) async => chapterContent;

  @override
  void clearBookCache(int bookId) {}

  @override
  void clearAllCache() {}

  @override
  String? getCachedContent(int bookId, int chapterId) => chapterContent;

  @override
  TextSpan? getCachedRichTextSpan(String bookId, int chapterId) => null;

  @override
  List<RichParagraph>? getCachedRichParagraphs(String bookId, int chapterId) =>
      null;

  @override
  String? getPageContent(int bookId, int chapterId, int pageIndex) =>
      chapterContent;

  @override
  ReadingProgressData? get currentProgress => progress;

  @override
  Future<void> clearReadingProgress(String bookId) async {}

  @override
  Future<List<ReadingProgressData>> getAllReadingProgress() async => [];

  @override
  void clearProgressCache() {}
}

class _MockNoteRepository implements NoteRepository {
  List<Note> notes = [];
  Note? lastCreatedNote;

  @override
  Future<List<Note>> getNotesForChapter(
    String bookId,
    int chapterIndex, {
    NoteType? noteType,
  }) async {
    var result = notes
        .where((n) => n.bookId == bookId && n.chapterIndex == chapterIndex)
        .toList();
    if (noteType != null) {
      result = result.where((n) => n.noteType == noteType).toList();
    }
    return result;
  }

  @override
  Future<Note> createNote(Note note) async {
    lastCreatedNote = note;
    notes.add(note);
    return note;
  }

  @override
  Future<void> deleteNote(String noteId) async {
    notes.removeWhere((n) => n.id == noteId);
  }

  @override
  Future<void> updateNote(Note note) async {
    final idx = notes.indexWhere((n) => n.id == note.id);
    if (idx >= 0) notes[idx] = note;
  }

  @override
  Future<NoteStats> getNoteStats(String bookId) async =>
      const NoteStats(totalCount: 0, highlightCount: 0, annotationCount: 0);

  @override
  Future<List<Note>> getNotes(String bookId, {NoteType? noteType}) async => [];
}

class _MockStatsRepo implements StatisticsRepository {
  @override
  Future<void> recordReadingSession(ReadingSession session) async {}

  @override
  Future<List<ReadingStats>> getReadingStatsRange({
    required String startDate,
    required String endDate,
  }) async => [];

  @override
  Future<GlobalStats> getGlobalReadingStats() async => const GlobalStats(
    totalReadingTimeSeconds: 0,
    totalCharactersRead: 0,
    booksReadCount: 0,
    booksCompletedCount: 0,
    consecutiveReadingDays: 0,
    todayReadingTimeSeconds: 0,
    todayCharactersRead: 0,
    averageReadingSpeed: 0,
    totalBooksCount: 0,
    totalNotesCount: 0,
    totalBookmarksCount: 0,
  );

  @override
  Future<List<ReadingSession>> getReadingSessions(
    String bookId, {
    int limit = 100,
  }) async => [];
}

ReaderViewModel createViewModel({
  _MockReaderRepository? repo,
  _MockReaderConfig? config,
  ReadingStatsService? statsService,
  _MockNoteRepository? noteRepo,
}) {
  return ReaderViewModel(
    repo ?? _MockReaderRepository(),
    config ?? _MockReaderConfig(),
    statsService ?? ReadingStatsService(_MockStatsRepo()),
    noteRepo ?? _MockNoteRepository(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReaderViewModel', () {
    late _MockReaderRepository repo;
    late _MockReaderConfig config;
    late ReadingStatsService statsService;
    late _MockNoteRepository noteRepo;
    late ReaderViewModel vm;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      repo = _MockReaderRepository(
        chapters: [
          createTestChapter(chapterIndex: 0, title: '第一章'),
          createTestChapter(chapterIndex: 1, title: '第二章'),
          createTestChapter(chapterIndex: 2, title: '第三章'),
        ],
        chapterContent: testChapterContent,
        pages: [
          PageInfo(
            pageIndex: 0,
            content: '第一页',
            startOffset: 0,
            endOffset: 100,
          ),
          PageInfo(
            pageIndex: 1,
            content: '第二页',
            startOffset: 100,
            endOffset: 200,
          ),
        ],
      );
      config = _MockReaderConfig();
      config.prefs = prefs;
      statsService = ReadingStatsService(_MockStatsRepo());
      noteRepo = _MockNoteRepository();
      vm = createViewModel(
        repo: repo,
        config: config,
        statsService: statsService,
        noteRepo: noteRepo,
      );
    });

    tearDown(() {
      vm.dispose();
    });

    group('初始化', () {
      test('构造后应从配置加载字体设置', () {
        expect(vm.fontSize.value, equals(ReaderFontSize.medium.size));
        expect(vm.lineHeight.value, equals(1.6));
        expect(vm.themeMode.value, equals(ThemeMode.light));
      });

      test('initialize 应加载章节列表和进度', () async {
        config.theme.value = ReaderTheme.dark;
        vm = createViewModel(
          repo: repo,
          config: config,
          statsService: statsService,
          noteRepo: noteRepo,
          bilingualService: bilingualService,
        );

        expect(vm.bookId.value, equals('0'));

        await vm.initialize('book_1');

        expect(vm.bookId.value, equals('book_1'));
        expect(vm.chapters.value.value?.length, equals(3));
        expect(vm.chapterIndex.value, equals(0));
        expect(vm.isLoading.value, isFalse);
      });

      test('initialize 应加载上次阅读进度', () async {
        repo = _MockReaderRepository(
          chapters: [createTestChapter(chapterIndex: 0)],
          chapterContent: testChapterContent,
          progress: ReadingProgressData(
            bookId: 'book_1',
            chapterIndex: 0,
            charOffset: 100,
            pageIndex: 0,
            totalPages: 2,
            readingTimeSeconds: 120,
            lastReadAt: DateTime(2026, 5, 18),
          ),
          pages: [
            PageInfo(
              pageIndex: 0,
              content: '第一页',
              startOffset: 0,
              endOffset: 100,
            ),
          ],
        );
        vm = createViewModel(repo: repo);

        await vm.initialize('book_1');

        expect(vm.currentCharOffset.value, equals(100));
        expect(vm.readingDuration.value, equals(120));
      });

      test('initialize 应加载书签', () async {
        repo = _MockReaderRepository(
          chapters: [createTestChapter(chapterIndex: 0)],
          chapterContent: testChapterContent,
          bookmarks: [createTestBookmark()],
          pages: [
            PageInfo(
              pageIndex: 0,
              content: '第一页',
              startOffset: 0,
              endOffset: 100,
            ),
          ],
        );
        vm = createViewModel(repo: repo);

        await vm.initialize('book_1');

        expect(vm.bookmarks.value.value?.length, equals(1));
      });

      test('initialize 在章节列表为空时应跳过加载', () async {
        repo = _MockReaderRepository(chapters: [], chapterContent: '');
        vm = createViewModel(repo: repo);

        await vm.initialize('book_1');

        expect(vm.chapterContent.value.value, isEmpty);
        expect(vm.isLoading.value, isFalse);
      });
    });

    group('章节导航', () {
      setUp(() async {
        await vm.initialize('book_1');
      });

      test('nextChapter 应加载下一章', () async {
        await vm.nextChapter();
        expect(vm.chapterIndex.value, equals(1));
      });

      test('nextChapter 在最后一章不应导航', () async {
        await vm.jumpToChapter(2);
        expect(vm.chapterIndex.value, equals(2));

        await vm.nextChapter();
        expect(vm.chapterIndex.value, equals(2));
      });

      test('previousChapter 应加载上一章', () async {
        await vm.jumpToChapter(1);
        expect(vm.chapterIndex.value, equals(1));

        await vm.previousChapter();
        expect(vm.chapterIndex.value, equals(0));
      });

      test('previousChapter 在第一章不应导航', () async {
        expect(vm.chapterIndex.value, equals(0));
        await vm.previousChapter();
        expect(vm.chapterIndex.value, equals(0));
      });

      test('jumpToChapter 应跳转到指定章节并关闭目录', () async {
        vm.toggleCatalog();
        expect(vm.showCatalog.value, isTrue);

        await vm.jumpToChapter(1);

        expect(vm.chapterIndex.value, equals(1));
        expect(vm.showCatalog.value, isFalse);
      });

      test('jumpToPosition 应跳转到指定章节和偏移', () async {
        await vm.jumpToPosition(2, 50);

        expect(vm.chapterIndex.value, equals(2));
        expect(vm.currentCharOffset.value, equals(50));
      });

      test('loadPage 应更新页码和偏移', () async {
        await vm.loadPage(1);

        expect(vm.pageIndex.value, equals(1));
      });

      test('loadPage 在超出范围时应无操作', () async {
        await vm.loadPage(99);

        expect(vm.pageIndex.value, equals(0));
      });
    });

    group('阅读进度保存', () {
      test('startReading 应开始计时和阅读会话', () {
        vm.startReading();

        expect(vm.isReading.value, isTrue);
        expect(statsService.isSessionActive, isTrue);
      });

      test('stopReading 应结束计时和阅读会话', () async {
        vm.startReading();
        expect(vm.isReading.value, isTrue);

        await vm.stopReading();

        expect(vm.isReading.value, isFalse);
        expect(statsService.isSessionActive, isFalse);
      });

      test('重复 startReading 不应重复创建会话', () {
        vm.startReading();
        final sessionId = statsService.currentSessionId;

        vm.startReading();

        expect(statsService.currentSessionId, equals(sessionId));
      });
    });

    group('UI 面板切换', () {
      test('toggleCatalog 应切换目录显示', () {
        expect(vm.showCatalog.value, isFalse);
        vm.toggleCatalog();
        expect(vm.showCatalog.value, isTrue);
        vm.toggleCatalog();
        expect(vm.showCatalog.value, isFalse);
      });

      test('toggleCatalog 应关闭书签面板', () {
        vm.toggleBookmarks();
        vm.toggleCatalog();
        expect(vm.showBookmarks.value, isFalse);
        expect(vm.showCatalog.value, isTrue);
      });

      test('toggleBookmarks 应切换书签面板', () {
        expect(vm.showBookmarks.value, isFalse);
        vm.toggleBookmarks();
        expect(vm.showBookmarks.value, isTrue);
      });

      test('toggleToolbar 应切换工具栏', () {
        expect(vm.showToolbar.value, isFalse);
        vm.toggleToolbar();
        expect(vm.showToolbar.value, isTrue);
      });
    });

    group('书签管理', () {
      setUp(() async {
        await vm.initialize('book_1');
      });

      test('loadBookmarks 应加载书签列表', () async {
        repo = _MockReaderRepository(
          chapters: [createTestChapter(chapterIndex: 0)],
          chapterContent: testChapterContent,
          bookmarks: [createTestBookmark()],
          pages: [
            PageInfo(
              pageIndex: 0,
              content: '第一页',
              startOffset: 0,
              endOffset: 100,
            ),
          ],
        );
        vm = createViewModel(repo: repo);

        await vm.loadBookmarks();

        expect(vm.bookmarks.value.value?.length, equals(1));
        expect(vm.bookmarks.value.value?.first.id, equals('bm_1'));
      });

      test('hasBookmarkAtCurrentPosition 应正确判断', () async {
        expect(vm.hasBookmarkAtCurrentPosition, isFalse);

        repo.bookmarks = [createTestBookmark(chapterIndex: 0, charOffset: 0)];
        vm = createViewModel(repo: repo);
        await vm.initialize('book_1');

        expect(vm.hasBookmarkAtCurrentPosition, isTrue);
      });

      test('toggleBookmarkAtCurrentPosition 无书签时应添加', () async {
        final result = await vm.toggleBookmarkAtCurrentPosition();

        expect(result, isTrue);
      });

      test('toggleBookmarkAtCurrentPosition 有书签时应删除', () async {
        repo = _MockReaderRepository(
          chapters: [createTestChapter(chapterIndex: 0)],
          chapterContent: testChapterContent,
          bookmarks: [createTestBookmark(chapterIndex: 0, charOffset: 0)],
          pages: [
            PageInfo(
              pageIndex: 0,
              content: '第一页',
              startOffset: 0,
              endOffset: 100,
            ),
          ],
        );
        vm = createViewModel(repo: repo);
        await vm.initialize('book_1');

        final result = await vm.toggleBookmarkAtCurrentPosition();

        expect(result, isTrue);
      });
    });

    group('文本选择和批注', () {
      test('updateSelection 应设置选中状态', () {
        vm.updateSelection('测试文本', 0, 4);

        expect(vm.selectedText.value, equals('测试文本'));
        expect(vm.selectionStart.value, equals(0));
        expect(vm.selectionEnd.value, equals(4));
        expect(vm.showSelectionToolbar.value, isTrue);
      });

      test('updateSelection 空文本应清除选中', () {
        vm.updateSelection('测试文本', 0, 4);
        expect(vm.showSelectionToolbar.value, isTrue);

        vm.updateSelection('', 0, 0);

        expect(vm.showSelectionToolbar.value, isFalse);
        expect(vm.selectedText.value, isEmpty);
      });

      test('clearSelection 应清除选中状态', () {
        vm.updateSelection('测试文本', 0, 4);
        vm.clearSelection();

        expect(vm.selectedText.value, isEmpty);
        expect(vm.selectionStart.value, equals(0));
        expect(vm.selectionEnd.value, equals(0));
        expect(vm.showSelectionToolbar.value, isFalse);
      });

      test('saveHighlight 应创建高亮笔记', () async {
        vm.updateSelection('测试文本', 0, 4);
        await vm.saveHighlight();

        expect(noteRepo.lastCreatedNote, isNotNull);
        expect(noteRepo.lastCreatedNote!.noteType, equals(NoteType.highlight));
        expect(noteRepo.lastCreatedNote!.selectedText, equals('测试文本'));
        expect(vm.showSelectionToolbar.value, isFalse);
      });

      test('saveAnnotation 应创建批注笔记', () async {
        vm.updateSelection('测试文本', 0, 4);
        await vm.saveAnnotation('这是批注内容');

        expect(noteRepo.lastCreatedNote, isNotNull);
        expect(noteRepo.lastCreatedNote!.noteType, equals(NoteType.annotation));
        expect(noteRepo.lastCreatedNote!.content, equals('这是批注内容'));
        expect(vm.showSelectionToolbar.value, isFalse);
      });

      test('deleteNote 应删除笔记', () async {
        final note = createTestNote();
        noteRepo.notes = [note];

        await vm.deleteNote(note.id);

        expect(noteRepo.notes.length, equals(0));
      });

      test('saveHighlight 选中文本为空时应无操作', () async {
        await vm.saveHighlight();

        expect(noteRepo.lastCreatedNote, isNull);
      });
    });

    group('阅读设置', () {
      test('setFontSize 应更新字体大小并重新加载章节', () async {
        config.fontSize.value = ReaderFontSize.medium;

        await vm.setFontSize(20);

        expect(vm.fontSize.value, equals(20));
        expect(config.fontSize.value.size, equals(20));
      });

      test('setLineHeight 应更新行间距并重新加载章节', () async {
        await vm.setLineHeight(2.0);

        expect(vm.lineHeight.value, equals(2.0));
        expect(config.lineHeight.value, equals(2.0));
      });

      test('setTheme 应更新主题', () async {
        await vm.setTheme(ThemeMode.dark);

        expect(vm.themeMode.value, equals(ThemeMode.dark));
      });

      test('setLetterSpacing 应更新字间距', () {
        vm.setLetterSpacing(2.0);
        expect(vm.letterSpacing.value, equals(2.0));
      });

      test('setParagraphSpacing 应更新段间距', () {
        vm.setParagraphSpacing(24.0);
        expect(vm.paragraphSpacing.value, equals(24.0));
      });

      test('setPageMargin 应更新页边距', () {
        vm.setPageMargin(32.0);
        expect(vm.pageMargin.value, equals(32.0));
      });

      test('setWritingDirection 应更新书写方向', () {
        vm.setWritingDirection(WritingDirection.vertical);
        expect(vm.writingDirection.value, equals(WritingDirection.vertical));
      });

      test('setReaderBgColor 应更新背景色', () {
        vm.setReaderBgColor(2);
        expect(vm.readerBgColorIndex.value, equals(2));
      });

      test('setBrightness 应裁剪到 0-1 范围', () {
        vm.setBrightness(1.5);
        expect(vm.brightnessOverlay.value, equals(1.0));

        vm.setBrightness(-0.5);
        expect(vm.brightnessOverlay.value, equals(0.0));

        vm.setBrightness(0.5);
        expect(vm.brightnessOverlay.value, equals(0.5));
      });
    });

    group('页面内搜索', () {
      test('toggleSearch 应切换搜索状态', () {
        expect(vm.showSearch.value, isFalse);
        vm.toggleSearch();
        expect(vm.showSearch.value, isTrue);
        vm.toggleSearch();
        expect(vm.showSearch.value, isFalse);
      });

      test('toggleSearch 关闭时应重置搜索状态', () {
        vm.updateSearch('测试', matches: 5, currentIndex: 2);
        vm.toggleSearch();
        vm.toggleSearch();

        expect(vm.searchQuery.value, isEmpty);
        expect(vm.searchMatches.value, equals(0));
        expect(vm.searchCurrentIndex.value, equals(0));
      });

      test('updateSearch 应更新搜索参数', () {
        vm.updateSearch('测试', matches: 5, currentIndex: 2, paragraphIndex: 3);

        expect(vm.searchQuery.value, equals('测试'));
        expect(vm.searchMatches.value, equals(5));
        expect(vm.searchCurrentIndex.value, equals(2));
        expect(vm.searchMatchParagraph.value, equals(3));
      });

      test('nextSearchMatch 应循环到下一个匹配', () {
        vm.updateSearch('测试', matches: 3);

        expect(vm.searchCurrentIndex.value, equals(0));
        vm.nextSearchMatch();
        expect(vm.searchCurrentIndex.value, equals(1));
        vm.nextSearchMatch();
        expect(vm.searchCurrentIndex.value, equals(2));
        vm.nextSearchMatch();
        expect(vm.searchCurrentIndex.value, equals(0));
      });

      test('prevSearchMatch 应循环到上一个匹配', () {
        vm.updateSearch('测试', matches: 3);

        expect(vm.searchCurrentIndex.value, equals(0));
        vm.prevSearchMatch();
        expect(vm.searchCurrentIndex.value, equals(2));
        vm.prevSearchMatch();
        expect(vm.searchCurrentIndex.value, equals(1));
      });

      test('nextSearchMatch 无匹配时应无操作', () {
        vm.nextSearchMatch();
        expect(vm.searchCurrentIndex.value, equals(0));
      });
    });

    group('计算属性', () {
      test('progressText 应返回进度百分比', () async {
        repo = _MockReaderRepository(
          chapters: [
            createTestChapter(chapterIndex: 0, title: '第一章'),
            createTestChapter(chapterIndex: 1, title: '第二章'),
          ],
          chapterContent: testChapterContent,
          pages: [
            PageInfo(
              pageIndex: 0,
              content: '内容',
              startOffset: 0,
              endOffset: 100,
            ),
          ],
        );
        vm = createViewModel(repo: repo);
        await vm.initialize('book_1');
        await vm.loadChapter(0);

        expect(vm.progressText, equals('50.0%'));
      });

      test('progressText 无章节时应返回 0%', () {
        expect(vm.progressText, equals('0%'));
      });

      test('currentChapterTitle 应返回当前章节标题', () async {
        repo = _MockReaderRepository(
          chapters: [createTestChapter(chapterIndex: 0, title: '第一章')],
          chapterContent: testChapterContent,
          pages: [
            PageInfo(
              pageIndex: 0,
              content: '内容',
              startOffset: 0,
              endOffset: 100,
            ),
          ],
        );
        vm = createViewModel(repo: repo);
        await vm.initialize('book_1');

        expect(vm.currentChapterTitle, equals('第一章'));
      });

      test('currentChapterTitle 无章节时应返回默认文本', () {
        expect(vm.currentChapterTitle, equals('加载中...'));
      });
    });

    group('阅读模式', () {
      test('setReadingMode 应更新阅读模式', () {
        vm.setReadingMode(ReadingMode.scroll);
        expect(vm.readingMode.value, equals(ReadingMode.scroll));

        vm.setReadingMode(ReadingMode.bilingual);
        expect(vm.readingMode.value, equals(ReadingMode.bilingual));
      });
    });

    group('清理资源', () {
      test('dispose 应停止阅读并清理定时器', () async {
        vm.startReading();
        expect(vm.isReading.value, isTrue);

        vm.dispose();

        expect(vm.isReading.value, isFalse);
      });
    });
  });
}
