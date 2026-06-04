import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/core/settings/persisted_signal.dart';
import 'package:zephyr_reader/features/reader/application/reader_view_model.dart';
import 'package:zephyr_reader/features/reader/data/repositories/rust_reader_repository.dart';
import 'package:zephyr_reader/src/rust/api/bilingual.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

import '../../helpers/fixtures.dart';

// ===== Mock classes using mocktail =====

class _MockReaderRepository extends Mock implements ReaderRepository {}

class _MockReaderConfig implements ReaderConfig {
  @override
  final SharedPreferences prefs = _MockSharedPreferences();
  @override
  late final theme = persistedEnum<ReaderTheme>(
    prefs,
    '',
    ReaderTheme.light,
    ReaderTheme.fromId,
    debounce: Duration.zero,
  );
  @override
  late final fontSize = persistedDouble(
    prefs,
    '',
    ReaderFontSize.medium.size,
    debounce: Duration.zero,
  );
  @override
  late final lineHeight = persistedDouble(
    prefs,
    '',
    1.6,
    debounce: Duration.zero,
  );
  @override
  late final paragraphSpacing = persistedDouble(
    prefs,
    '',
    12.0,
    debounce: Duration.zero,
  );
  @override
  late final padding = persistedDouble(
    prefs,
    '',
    16.0,
    debounce: Duration.zero,
  );
  @override
  late final readerBgColorIndex = persistedInt(
    prefs,
    '',
    0,
    debounce: Duration.zero,
  );
  @override
  late final autoScroll = persistedBool(
    prefs,
    '',
    false,
    debounce: Duration.zero,
  );
  @override
  late final autoScrollSpeed = persistedInt(
    prefs,
    '',
    30,
    debounce: Duration.zero,
  );
  @override
  late final letterSpacing = persistedDouble(
    prefs,
    '',
    0.0,
    debounce: Duration.zero,
  );
  @override
  late final tapLayout = persistedEnum<TapLayout>(
    prefs,
    '',
    TapLayout.rightHanded,
    (name) => TapLayout.values.firstWhere(
      (e) => e.name == name,
      orElse: () => TapLayout.rightHanded,
    ),
    debounce: Duration.zero,
  );
  @override
  late final punctuationSqueeze = persistedBool(
    prefs,
    '',
    true,
    debounce: Duration.zero,
  );
  @override
  late final baselineAlign = persistedBool(
    prefs,
    '',
    true,
    debounce: Duration.zero,
  );
  @override
  final writingDirection = signal<WritingDirection>(
    WritingDirection.horizontal,
  );
  @override
  final brightnessOverlay = signal<double>(0.0);

  @override
  double get pageMargin => padding.value;

  @override
  double get fontSizeValue => ReaderFontSize.fromSize(fontSize.value).size;

  @override
  Future<void> resetToDefault() async {
    theme.value = ReaderTheme.light;
    fontSize.value = ReaderFontSize.medium.size;
    lineHeight.value = 1.6;
    paragraphSpacing.value = 12.0;
    padding.value = 16.0;
    readerBgColorIndex.value = 0;
    autoScroll.value = false;
    autoScrollSpeed.value = 30;
    letterSpacing.value = 0.0;
    punctuationSqueeze.value = true;
    baselineAlign.value = true;
    tapLayout.value = TapLayout.rightHanded;
  }
}

class _MockBookmarkController extends Mock implements BookmarkController {}

class _MockReaderSearchController extends Mock
    implements ReaderSearchController {}

class _MockAnnotationController extends Mock implements AnnotationController {}

class _MockBilingualController extends Mock implements BilingualController {}

class _MockSharedPreferences extends Mock implements SharedPreferences {
  _MockSharedPreferences() {
    when(() => setDouble(any(), any())).thenAnswer((_) async => true);
    when(() => setBool(any(), any())).thenAnswer((_) async => true);
    when(() => setInt(any(), any())).thenAnswer((_) async => true);
    when(() => setString(any(), any())).thenAnswer((_) async => true);
    when(() => remove(any())).thenAnswer((_) async => true);
  }
}

// ===== Helper function to create ViewModel =====

ReaderViewModel createViewModel({
  ReaderRepository? repo,
  ReaderConfig? config,
  BookmarkController? bookmarkController,
  ReaderSearchController? searchController,
  AnnotationController? annotationController,
  BilingualController? bilingualController,
}) {
  return ReaderViewModel(
    repo ?? _MockReaderRepository(),
    config ?? _MockReaderConfig(),
    bookmarkController ?? _MockBookmarkController(),
    searchController ?? _MockReaderSearchController(),
    annotationController ?? _MockAnnotationController(),
    bilingualController ?? _MockBilingualController(),
  );
}

void main() {
  // ===== Set up mocktail defaults =====
  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(ReaderTheme.light);
    registerFallbackValue(ReaderFontSize.medium);
    registerFallbackValue(ThemeMode.light);
    registerFallbackValue(WritingDirection.horizontal);
    registerFallbackValue(ReadingMode.pagination);
  });

  group('ReaderViewModel', () {
    late ReaderRepository repo;
    late ReaderConfig config;
    late BookmarkController bookmarkController;
    late ReaderSearchController searchController;
    late AnnotationController annotationController;
    late BilingualController bilingualController;
    late ReaderViewModel vm;

    setUp(() async {
      // Setup SharedPreferences
      final mockPrefs = _MockSharedPreferences();
      when(() => mockPrefs.getString(any())).thenReturn(null);
      when(() => mockPrefs.getInt(any())).thenReturn(0);
      when(
        () => mockPrefs.setDouble(any(), any()),
      ).thenAnswer((_) async => true);
      when(
        () => mockPrefs.setString(any(), any()),
      ).thenAnswer((_) async => true);
      when(() => mockPrefs.setInt(any(), any())).thenAnswer((_) async => true);
      when(() => mockPrefs.setBool(any(), any())).thenAnswer((_) async => true);
      when(() => mockPrefs.remove(any())).thenAnswer((_) async => true);
      when(() => mockPrefs.containsKey(any())).thenReturn(false);
      when(() => mockPrefs.clear()).thenAnswer((_) async => true);

      // Setup mocks
      repo = _MockReaderRepository();
      config = _MockReaderConfig();
      bookmarkController = _MockBookmarkController();
      searchController = _MockReaderSearchController();
      annotationController = _MockAnnotationController();
      bilingualController = _MockBilingualController();

      // Configure bookmark controller mocks
      when(
        () => bookmarkController.bookmarks,
      ).thenAnswer((_) => asyncSignal<List<Bookmark>>(AsyncState.data([])));

      // Configure search controller mocks
      final showSearchSig = signal<bool>(false);
      when(() => searchController.showSearch).thenAnswer((_) => showSearchSig);
      when(() => searchController.toggleSearch()).thenAnswer((_) {
        showSearchSig.value = !showSearchSig.value;
      });
      when(
        () => searchController.searchQuery,
      ).thenAnswer((_) => signal<String>(''));
      when(
        () => searchController.searchMatches,
      ).thenAnswer((_) => signal<int>(0));
      when(
        () => searchController.searchCurrentIndex,
      ).thenAnswer((_) => signal<int>(0));
      when(
        () => searchController.searchMatchParagraph,
      ).thenAnswer((_) => signal<int>(0));
      when(
        () => searchController.updateSearch(
          any<String>(),
          matches: any(named: 'matches'),
          currentIndex: any(named: 'currentIndex'),
        ),
      ).thenAnswer((_) {});
      when(() => searchController.nextSearchMatch()).thenAnswer((_) {});
      when(() => searchController.prevSearchMatch()).thenAnswer((_) {});

      // Configure annotation controller mocks
      when(
        () => annotationController.selectedText,
      ).thenReturn(signal<String>(''));
      when(
        () => annotationController.selectionStart,
      ).thenReturn(signal<int>(0));
      when(() => annotationController.selectionEnd).thenReturn(signal<int>(0));
      when(
        () => annotationController.showSelectionToolbar,
      ).thenReturn(signal<bool>(false));
      when(
        () => annotationController.highlights,
      ).thenReturn(signal<List<Note>>([]));
      when(
        () => annotationController.updateSelection(
          any<String>(),
          any<int>(),
          any<int>(),
        ),
      ).thenAnswer((_) {});
      when(() => annotationController.clearSelection()).thenAnswer((_) {});

      // Configure bilingual controller mocks
      when(
        () => bilingualController.bilingualAlignment,
      ).thenReturn(asyncSignal<BilingualAlignment?>(AsyncState.data(null)));
      when(
        () => bilingualController.translationContent,
      ).thenReturn(signal<String>(''));

      // Configure repo mocks with default data
      when(() => repo.getChapters(any())).thenAnswer(
        (_) async => [
          Chapter(
            id: 'ch_1',
            bookId: 'book_1',
            title: '第一章',
            chapterIndex: 0,
            wordCount: 5000,
            cachedAt: DateTime.now(),
            level: 0,
            startIndex: 0,
            endIndex: 5000,
            contentLength: 5000,
          ),
          Chapter(
            id: 'ch_2',
            bookId: 'book_1',
            title: '第二章',
            chapterIndex: 1,
            wordCount: 5000,
            cachedAt: DateTime.now(),
            level: 0,
            startIndex: 0,
            endIndex: 5000,
            contentLength: 5000,
          ),
          Chapter(
            id: 'ch_3',
            bookId: 'book_1',
            title: '第三章',
            chapterIndex: 2,
            wordCount: 5000,
            cachedAt: DateTime.now(),
            level: 0,
            startIndex: 0,
            endIndex: 5000,
            contentLength: 5000,
          ),
        ],
      );
      when(
        () => repo.calculatePages(
          bookId: any(named: 'bookId'),
          chapterId: any(named: 'chapterId'),
          fontSize: any(named: 'fontSize'),
          lineHeight: any(named: 'lineHeight'),
          width: any(named: 'width'),
          height: any(named: 'height'),
          padding: any(named: 'padding'),
        ),
      ).thenAnswer(
        (_) async => [
          PageInfo(
            pageIndex: 0,
            content: '第一页',
            startOffset: 0,
            endOffset: 100,
          ),
          PageInfo(
            pageIndex: 0,
            content: '第二页',
            startOffset: 100,
            endOffset: 200,
          ),
        ],
      );

      // Configure repo methods used by loadChapter
      when(
        () => repo.loadChapterContent(any(), any()),
      ).thenAnswer((_) async => '测试章节内容。' * 100);
      when(
        () => repo.getPaginatedChapterPages(
          bookId: any(named: 'bookId'),
          chapterIndex: any(named: 'chapterIndex'),
          fontSize: any(named: 'fontSize'),
          lineHeight: any(named: 'lineHeight'),
          width: any(named: 'width'),
          height: any(named: 'height'),
          padding: any(named: 'padding'),
          devicePixelRatio: any(named: 'devicePixelRatio'),
          calibration: any(named: 'calibration'),
          fontFamily: any(named: 'fontFamily'),
        ),
      ).thenAnswer(
        (_) async => (
          cacheHit: false,
          isFallback: false,
          pages: [
            PageInfo(
              pageIndex: 0,
              content: '测试内容',
              startOffset: 0,
              endOffset: 4,
            ),
          ],
        ),
      );
      when(() => repo.loadReadingProgress(any())).thenAnswer((_) async => null);
      when(() => repo.currentPages).thenReturn(null);
      when(() => repo.preloadChapter(any(), any())).thenAnswer((_) async {});
      when(
        () => repo.updateReadingProgress(
          bookId: any(named: 'bookId'),
          chapterId: any(named: 'chapterId'),
          charOffset: any(named: 'charOffset'),
          pageIndex: any(named: 'pageIndex'),
          totalPages: any(named: 'totalPages'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => repo.addBookmark(any(), any(), any()),
      ).thenAnswer((_) async => createTestBookmark());
      when(() => repo.deleteBookmark(any())).thenAnswer((_) async => true);
      when(() => repo.loadReadingProgress(any())).thenAnswer((_) async => null);
      when(() => repo.currentProgress).thenReturn(null);
      when(() => repo.clearReadingProgress(any())).thenAnswer((_) async {});

      // Create ViewModel
      vm = createViewModel(
        repo: repo,
        config: config,
        bookmarkController: bookmarkController,
        searchController: searchController,
        annotationController: annotationController,
        bilingualController: bilingualController,
      );
    });

    tearDown(() {
      // vm.resetForNewBook();
    });

    group('初始化', () {
      test('构造后应从配置加载字体设置', () {
        expect(vm.fontSizeDouble.value, equals(16.0));
        expect(vm.config.lineHeight.value, equals(1.6));
        expect(vm.config.theme.value, equals(ReaderTheme.light));
      });

      test('initialize 应加载章节列表和进度', () async {
        config.theme.value = ReaderTheme.dark;

        vm = createViewModel(
          repo: repo,
          config: config,
          bookmarkController: bookmarkController,
          searchController: searchController,
          annotationController: annotationController,
          bilingualController: bilingualController,
        );

        expect(vm.bookId.value, equals('0'));

        await vm.initialize('book_1');

        expect(vm.bookId.value, equals('book_1'));
        expect(vm.chapters.value.value?.length, equals(3));
        expect(vm.chapterIndex.value, equals(0));
        expect(vm.isLoading.value, isFalse);
      });
      test('initialize 在章节列表为空时应跳过加载', () async {
        when(() => repo.getChapters(any())).thenAnswer((_) async => []);
        vm = createViewModel(
          repo: repo,
          config: config,
          bookmarkController: bookmarkController,
          searchController: searchController,
          annotationController: annotationController,
          bilingualController: bilingualController,
        );

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
        when(
          () => repo.getChapter(any(), 1),
        ).thenAnswer((_) async => createTestChapter(chapterIndex: 1));
        await vm.nextChapter();
        expect(vm.chapterIndex.value, equals(1));
      });

      test('previousChapter 应加载上一章', () async {
        when(
          () => repo.getChapter(any(), 0),
        ).thenAnswer((_) async => createTestChapter(chapterIndex: 0));
        await vm.jumpToChapter(1);
        expect(vm.chapterIndex.value, equals(1));

        await vm.previousChapter();
        expect(vm.chapterIndex.value, equals(0));
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

    group('阅读设置', () {
      test('setFontSize 应更新字体大小', () async {
        await vm.setFontSize(20);

        expect(vm.fontSizeDouble.value, equals(20));
      });

      test('setLineHeight 应更新行间距', () async {
        await vm.setLineHeight(2.0);

        expect(vm.config.lineHeight.value, equals(2.0));
      });

      test('setReaderBgColor 应更新背景色索引', () {
        config.readerBgColorIndex.value = 2;
        expect(vm.config.readerBgColorIndex.value, equals(2));
      });

      test('setLetterSpacing 应更新字间距', () {
        config.letterSpacing.value = 2.0;
        expect(vm.config.letterSpacing.value, equals(2.0));
      });

      test('setParagraphSpacing 应更新段间距', () {
        config.paragraphSpacing.value = 24.0;
        expect(vm.config.paragraphSpacing.value, equals(24.0));
      });

      test('setPageMargin 应更新页边距', () {
        config.padding.value = 32.0;
        expect(vm.config.padding.value, equals(32.0));
      });

      test('setWritingDirection 应更新书写方向', () {
        config.writingDirection.value = WritingDirection.vertical;
        expect(
          vm.config.writingDirection.value,
          equals(WritingDirection.vertical),
        );
      });

      test('setBrightness 应更新亮度遮罩', () {
        config.brightnessOverlay.value = 1.5;
        expect(vm.config.brightnessOverlay.value, equals(1.5));

        config.brightnessOverlay.value = 0.0;
        expect(vm.config.brightnessOverlay.value, equals(0.0));

        config.brightnessOverlay.value = 0.5;
        expect(vm.config.brightnessOverlay.value, equals(0.5));
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

      test('updateSearch 应更新搜索参数', () {
        vm.updateSearch('测试', matches: 5, currentIndex: 2);

        verify(
          () =>
              searchController.updateSearch('测试', matches: 5, currentIndex: 2),
        ).called(1);
      });

      test('nextSearchMatch 应循环到下一个匹配', () {
        vm.nextSearchMatch();
        verify(() => searchController.nextSearchMatch()).called(1);
      });

      test('prevSearchMatch 应循环到上一个匹配', () {
        vm.prevSearchMatch();
        verify(() => searchController.prevSearchMatch()).called(1);
      });
    });

    group('文本选择', () {
      test('updateSelection 应设置选中状态', () {
        vm.updateSelection('测试文本', 0, 4);

        verify(
          () => annotationController.updateSelection('测试文本', 0, 4),
        ).called(1);
      });

      test('clearSelection 应清除选中状态', () {
        vm.clearSelection();

        verify(() => annotationController.clearSelection()).called(1);
      });
    });
  });
}
