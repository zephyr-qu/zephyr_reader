import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signals_core/signals_core.dart';
import 'package:zephyr_reader/features/reader/application/reader_enums.dart';
import 'package:zephyr_reader/features/reader/application/reader_view_model.dart';
import 'package:zephyr_reader/features/reader/application/reader_config.dart';
import 'package:zephyr_reader/features/reader/application/reader_search_controller.dart';
import 'package:zephyr_reader/features/reader/application/annotation_controller.dart';
import 'package:zephyr_reader/features/reader/application/bookmark_controller.dart';
import 'package:zephyr_reader/features/reader/application/bilingual_controller.dart';
import 'package:zephyr_reader/features/reader/application/reader_settings_controller.dart';
import 'package:zephyr_reader/features/reader/data/repositories/rust_reader_repository.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

import '../../helpers/fixtures.dart';

// ===== Mock classes using mocktail =====

class _MockReaderRepository extends Mock implements ReaderRepository {}

class _MockReaderConfig extends Mock implements ReaderConfig {}

class _MockReaderSettingsController extends Mock
    implements ReaderSettingsController {}

class _MockBookmarkController extends Mock implements BookmarkController {}

class _MockReaderSearchController extends Mock
    implements ReaderSearchController {}

class _MockAnnotationController extends Mock implements AnnotationController {}

class _MockBilingualController extends Mock implements BilingualController {}

class _MockSharedPreferences extends Mock implements SharedPreferences {}

// ===== Helper function to create ViewModel =====

ReaderViewModel createViewModel({
  ReaderRepository? repo,
  ReaderConfig? config,
  ReaderSettingsController? settingsController,
  BookmarkController? bookmarkController,
  ReaderSearchController? searchController,
  AnnotationController? annotationController,
  BilingualController? bilingualController,
}) {
  return ReaderViewModel(
    repo ?? _MockReaderRepository(),
    config ?? _MockReaderConfig(),
    settingsController ?? _MockReaderSettingsController(),
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
    late ReaderSettingsController settingsController;
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
      settingsController = _MockReaderSettingsController();
      bookmarkController = _MockBookmarkController();
      searchController = _MockReaderSearchController();
      annotationController = _MockAnnotationController();
      bilingualController = _MockBilingualController();

      // Configure settings controller mocks
      when(() => settingsController.fontSize).thenReturn(signal<double>(16.0));
      when(() => settingsController.lineHeight).thenReturn(signal<double>(1.6));
      when(
        () => settingsController.readerTheme,
      ).thenReturn(signal(ReaderTheme.light));
      when(
        () => settingsController.letterSpacing,
      ).thenReturn(signal<double>(0.0));
      when(
        () => settingsController.paragraphSpacing,
      ).thenReturn(signal<double>(16.0));
      when(
        () => settingsController.pageMargin,
      ).thenReturn(signal<double>(32.0));
      when(
        () => settingsController.writingDirection,
      ).thenReturn(signal(WritingDirection.horizontal));
      when(
        () => settingsController.readerBgColorIndex,
      ).thenReturn(signal<int>(0));
      when(
        () => settingsController.brightnessOverlay,
      ).thenReturn(signal<double>(0.0));
      when(
        () => settingsController.setFontSize(any()),
      ).thenAnswer((_) async {});
      when(
        () => settingsController.setLineHeight(any()),
      ).thenAnswer((_) async {});
      when(() => settingsController.setTheme(any())).thenAnswer((_) async {});
      when(
        () => settingsController.setLetterSpacing(any()),
      ).thenAnswer((_) async {});
      when(
        () => settingsController.setParagraphSpacing(any()),
      ).thenAnswer((_) async {});
      when(
        () => settingsController.setPageMargin(any()),
      ).thenAnswer((_) async {});
      when(
        () => settingsController.setWritingDirection(any()),
      ).thenAnswer((_) async {});
      when(
        () => settingsController.setReaderBgColor(any()),
      ).thenAnswer((_) async {});
      when(
        () => settingsController.setBrightness(any()),
      ).thenAnswer((_) async {});

      // Configure bookmark controller mocks
      when(
        () => bookmarkController.bookmarks,
      ).thenReturn(asyncSignal<List<Bookmark>>(AsyncState.data([])));

      // Configure search controller mocks
      when(() => searchController.showSearch).thenReturn(signal<bool>(false));
      when(() => searchController.searchQuery).thenReturn(signal<String>(''));
      when(() => searchController.searchMatches).thenReturn(signal<int>(0));
      when(
        () => searchController.searchCurrentIndex,
      ).thenReturn(signal<int>(0));
      when(
        () => searchController.searchMatchParagraph,
      ).thenReturn(signal<int>(0));
      when(() => searchController.toggleSearch()).thenAnswer((_) {});
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
      ).thenReturn(asSignal<List<dynamic>>([]));
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
      ).thenReturn(asyncSignal<BilingualAlignment?>(null));
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
        () => repo.loadChapterContent(any(), any()),
      ).thenAnswer((_) async => testChapterContent);
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
            pageIndex: 1,
            content: '第二页',
            startOffset: 100,
            endOffset: 200,
          ),
        ],
      );
      when(() => repo.getBookmarks(any())).thenAnswer((_) async => []);
      when(
        () => repo.addBookmark(any(), any(), any()),
      ).thenAnswer((_) async => createTestBookmark());
      when(() => repo.deleteBookmark(any())).thenAnswer((_) async => true);
      when(
        () => repo.updateReadingProgress(
          bookId: any(named: 'bookId'),
          chapterId: any(named: 'chapterId'),
          charOffset: any(named: 'charOffset'),
          pageIndex: any(named: 'pageIndex'),
          totalPages: any(named: 'totalPages'),
        ),
      ).thenAnswer((_) async {});
      when(() => repo.loadReadingProgress(any())).thenAnswer((_) async => null);
      when(() => repo.currentProgress).thenReturn(null);
      when(() => repo.clearReadingProgress(any())).thenAnswer((_) async {});

      // Configure reader config mocks
      when(
        () => config.theme,
      ).thenReturn(signal<ReaderTheme>(ReaderTheme.light));
      when(
        () => config.fontSize,
      ).thenReturn(signal<ReaderFontSize>(ReaderFontSize.medium));
      when(() => config.lineHeight).thenReturn(signal<double>(1.6));
      when(() => config.paragraphSpacing).thenReturn(signal<double>(16.0));
      when(() => config.padding).thenReturn(signal<double>(16.0));
      when(() => config.autoScroll).thenReturn(signal<bool>(false));
      when(() => config.autoScrollSpeed).thenReturn(signal<int>(30));
      when(() => config.readerBgColorIndex).thenReturn(signal<int>(0));
      when(() => config.setTheme(any())).thenAnswer((_) async {
        return null;
      });
      when(() => config.setFontSize(any())).thenAnswer((_) async {
        return null;
      });
      when(() => config.setLineHeight(any())).thenAnswer((_) async {
        return null;
      });
      when(() => config.setParagraphSpacing(any())).thenAnswer((_) async {
        return null;
      });
      when(() => config.setPadding(any())).thenAnswer((_) async {
        return null;
      });
      when(() => config.setAutoScroll(any())).thenAnswer((_) async {
        return null;
      });
      when(() => config.setAutoScrollSpeed(any())).thenAnswer((_) async {
        return null;
      });

      // Create ViewModel
      vm = createViewModel(
        repo: repo,
        config: config,
        settingsController: settingsController,
        bookmarkController: bookmarkController,
        searchController: searchController,
        annotationController: annotationController,
        bilingualController: bilingualController,
      );
    });

    tearDown(() {
      vm.dispose();
    });

    group('初始化', () {
      test('构造后应从配置加载字体设置', () {
        expect(vm.fontSize.value, equals(16.0));
        expect(vm.lineHeight.value, equals(1.6));
        expect(vm.themeMode.value, equals(ReaderTheme.light));
      });

      test('initialize 应加载章节列表和进度', () async {
        when(
          () => config.theme,
        ).thenReturn(signal<ReaderTheme>(ReaderTheme.dark));

        vm = createViewModel(
          repo: repo,
          config: config,
          settingsController: settingsController,
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

        expect(vm.fontSize.value, equals(20));
      });

      test('setLineHeight 应更新行间距', () async {
        await vm.setLineHeight(2.0);

        expect(vm.lineHeight.value, equals(2.0));
      });

      test('setReaderBgColor 应更新背景色索引', () {
        vm.setReaderBgColor(2);
        expect(vm.readerBgColorIndex.value, equals(2));
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
