import 'dart:ui' show TextAlign;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zephyr_reader/core/local/preferences_service.dart';
import 'package:zephyr_reader/features/reader/domain/model/page_info.dart';
import 'package:zephyr_reader/core/settings/persisted_signal.dart';
import 'package:zephyr_reader/features/reader/data/pagination_params.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_load_phase.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_pagination_intent.dart';
import 'package:zephyr_reader/features/reader/data/repositories/rust_reader_repository.dart';
import 'package:zephyr_reader/features/reader/data/pagination_engine.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/src/rust/domain/types/typeset.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_view_model.dart';
import '../../helpers/fixtures.dart';

// ===== Mocks =====

class _MockRepo extends Mock implements ReaderRepository {}

class _MockSharedPreferences extends Mock implements PreferencesService {
  _MockSharedPreferences() {
    when(
      () => getDouble(any(), defaultValue: any(named: 'defaultValue')),
    ).thenAnswer(
      (invocation) => invocation.namedArguments[#defaultValue] as double,
    );
    when(
      () => getInt(any(), defaultValue: any(named: 'defaultValue')),
    ).thenAnswer(
      (invocation) => invocation.namedArguments[#defaultValue] as int,
    );
    when(
      () => getBool(any(), defaultValue: any(named: 'defaultValue')),
    ).thenAnswer(
      (invocation) => invocation.namedArguments[#defaultValue] as bool,
    );
    when(() => getString(any())).thenReturn(null);
    when(() => setDouble(any(), any())).thenAnswer((_) async => true);
    when(() => setBool(any(), any())).thenAnswer((_) async => true);
    when(() => setInt(any(), any())).thenAnswer((_) async => true);
    when(() => setString(any(), any())).thenAnswer((_) async => true);
    when(() => remove(any())).thenAnswer((_) async => true);
  }
}

class _MockConfig implements ReaderConfig {
  @override
  final PreferencesService prefs = _MockSharedPreferences();

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
    16.0,
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
    16.0,
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
  late final firstLineIndent = persistedBool(
    prefs,
    '',
    true,
    debounce: Duration.zero,
  );

  @override
  late final enableHyphenation = persistedBool(
    prefs,
    '',
    false,
    debounce: Duration.zero,
  );

  @override
  late final language = persistedEnum<LanguageType>(
    prefs,
    '',
    LanguageType.auto,
    (name) => LanguageType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => LanguageType.auto,
    ),
    debounce: Duration.zero,
  );

  @override
  late final autoSpaceRatio = persistedDouble(
    prefs,
    '',
    0.25,
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
  final writingDirection = signal<WritingDirection>(
    WritingDirection.horizontal,
  );

  @override
  final brightnessOverlay = signal<double>(0.0);
  @override
  late final followSystemFontScale = persistedBool(
    prefs,
    '',
    false,
    debounce: Duration.zero,
  );

  @override
  late final textAlign = persistedEnum<TextAlign>(
    prefs,
    '',
    TextAlign.justify,
    (name) => TextAlign.values.firstWhere(
      (e) => e.name == name,
      orElse: () => TextAlign.justify,
    ),
    debounce: Duration.zero,
  );

  @override
  Future<void> resetToDefault() async {
    theme.value = ReaderTheme.light;
    fontSize.value = 16.0;
    lineHeight.value = 1.6;
    paragraphSpacing.value = 16.0;
    padding.value = 16.0;
    readerBgColorIndex.value = 0;
    autoScroll.value = false;
    autoScrollSpeed.value = 30;
    letterSpacing.value = 0.0;
    punctuationSqueeze.value = true;

    baselineAlign.value = true;
    firstLineIndent.value = true;
    enableHyphenation.value = false;
    autoSpaceRatio.value = 0.25;
    language.reset();
    tapLayout.value = TapLayout.rightHanded;
  }

  @override
  void dispose() {}
}

// ===== Helpers =====

ChapterViewModel createManager({ReaderRepository? repo, ReaderConfig? config}) {
  return ChapterViewModel(repo ?? _MockRepo(), config ?? _MockConfig());
}

/// Mock 设置 `expandToFullChapter` 成功返回 2 页。
void _setupPaginateChapter(_MockRepo repo, {bool isFallback = false}) {
  when(
    () => repo.expandToFullChapter(
      bookId: any(named: 'bookId'),
      chapterIndex: any(named: 'chapterIndex'),
      params: any(named: 'params'),
    ),
  ).thenAnswer(
    (_) async => isFallback
        ? (totalPages: 0, isPartial: false)
        : (totalPages: 2, isPartial: false),
  );

  if (isFallback) {
    when(() => repo.descriptors).thenReturn(null);
  } else {
    when(() => repo.descriptors).thenReturn([
      const PageDescriptor(
        pageIndex: 0,
        startOffset: 0,
        endOffset: 50,
        isLastPage: false,
      ),
      const PageDescriptor(
        pageIndex: 1,
        startOffset: 50,
        endOffset: 100,
        isLastPage: true,
      ),
    ]);
  }
}

void _setupBeginPaginate(_MockRepo repo) {
  when(
    () => repo.beginPaginate(
      bookId: any(named: 'bookId'),
      chapterIndex: any(named: 'chapterIndex'),
      params: any(named: 'params'),
      maxChars: any(named: 'maxChars'),
    ),
  ).thenAnswer((_) async => (totalPages: 2, isPartial: false));
}

/// Capture the [PaginationParams] passed to [beginPaginate] for assertion.
void _setupBeginPaginateCapturing(_MockRepo repo, List<PaginationParams> sink) {
  when(
    () => repo.beginPaginate(
      bookId: any(named: 'bookId'),
      chapterIndex: any(named: 'chapterIndex'),
      params: any(named: 'params'),
      maxChars: any(named: 'maxChars'),
    ),
  ).thenAnswer((invocation) async {
    final params = invocation.namedArguments[#params] as PaginationParams;
    sink.add(params);
    return (totalPages: 2, isPartial: false);
  });
}

void _registerFallbackValues() {
  registerFallbackValue(ReadingMode.pagination);
  registerFallbackValue(
    const PaginationParams(
      fontSize: 16,
      lineHeight: 1.5,
      width: 400,
      height: 600,
      padding: 16,
    ),
  );
}

void main() {
  late _MockRepo repo;
  late _MockConfig config;
  late ChapterViewModel manager;

  setUpAll(() {
    _registerFallbackValues();
  });

  setUp(() {
    repo = _MockRepo();
    config = _MockConfig();

    // ReaderRepository default mocks
    when(
      () => repo.getChapters(any()),
    ).thenAnswer((_) async => createTestChapters(count: 3));
    when(
      () => repo.loadChapterContent(
        any(),
        any(),
        readingMode: any(named: 'readingMode'),
      ),
    ).thenAnswer((_) async => 'A' * 100);
    _setupPaginateChapter(repo);
    _setupBeginPaginate(repo);
    when(() => repo.loadReadingProgress(any())).thenAnswer((_) async => null);
    when(
      () => repo.loadChapterFirstSpine(any(), any()),
    ).thenAnswer((_) async => 'A' * 100);
    when(() => repo.warmPageCache(any(), any())).thenReturn(null);
    when(
      () => repo.preloadNextChapterStaging(
        any(),
        any(),
        fontSize: any(named: 'fontSize'),
        lineHeight: any(named: 'lineHeight'),
        width: any(named: 'width'),
        height: any(named: 'height'),
        padding: any(named: 'padding'),
        devicePixelRatio: any(named: 'devicePixelRatio'),
        fontFamily: any(named: 'fontFamily'),
      ),
    ).thenAnswer((_) async {});
    when(() => repo.preloadChapter(any(), any())).thenAnswer((_) async {});
    when(() => repo.clearNextChapterStaging()).thenReturn(null);
    when(() => repo.ensurePageWindow(any())).thenReturn(null);
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
        const PageInfo(
          pageIndex: 0,
          content: 'fallback',
          startOffset: 0,
          endOffset: 10,
        ),
      ],
    );

    manager = createManager(repo: repo, config: config);
  });

  group('ChapterManager', () {
    // ==================== 初始状态 ====================

    group('初始状态', () {
      test('创建时所有信号应有默认值', () {
        expect(manager.bookId.value, '0');
        expect(manager.chapterIndex.value, 0);
        expect(manager.totalPages.value, 0);
        expect(manager.pageIndex.value, 0);
        expect(manager.currentCharOffset.value, 0);
        expect(manager.pendingJumpCharOffset.value, null);
        expect(manager.isLoading.value, false);
        expect(manager.error.value, null);
        expect(manager.autoScrollTick.value, 0);
        expect(manager.pageWidth, 400);
        expect(manager.pageHeight, 600);
        expect(manager.devicePixelRatio, 1.0);
      });
    });

    // ==================== 章节列表加载 ====================

    group('loadChapters()', () {
      test('成功加载章节列表', () async {
        final chapters = createTestChapters(count: 3);
        when(() => repo.getChapters(any())).thenAnswer((_) async => chapters);

        await manager.loadChapters();

        expect(manager.chapters.value.value?.length, 3);
        expect(manager.chapters.value.hasValue, isTrue);
      });

      test('加载失败应抛异常并设置错误状态', () async {
        when(() => repo.getChapters(any())).thenThrow(Exception('db error'));

        await expectLater(manager.loadChapters(), throwsA(isA<Exception>()));
        expect(manager.chapters.value.hasError, isTrue);
      });

      test('加载期间状态标记为 loading', () async {
        final completer = Completer<List<Chapter>>();
        when(() => repo.getChapters(any())).thenAnswer((_) => completer.future);

        final future = manager.loadChapters();
        expect(manager.chapters.value.isLoading, isTrue);

        completer.complete(createTestChapters(count: 3));
        await future;
        expect(manager.chapters.value.isLoading, isFalse);
      });
    });

    // ==================== 章节内容加载 ====================

    group('loadChapter()', () {
      test('成功加载章节并更新分页信号', () async {
        await manager.loadChapter(1);

        expect(manager.chapterIndex.value, 1);
        expect(manager.totalPages.value, 2);
        expect(manager.pageIndex.value, 0);
        expect(manager.currentCharOffset.value, 0);
        expect(manager.pendingJumpCharOffset.value, 0);
        expect(manager.error.value, null);
        expect(manager.isLoading.value, false);
        expect(manager.chapterContent.value.value, equals('A' * 100));
      });

      test('initialCharOffset 定位到正确渲染行', () async {
        await manager.loadChapter(0, initialCharOffset: 60);

        expect(manager.currentCharOffset.value, 60);
        // offset 60 落在第二页 (startOffset=50, endOffset=100)
        expect(manager.pageIndex.value, 1);
      });

      test('initialCharOffset 超 content 长度时归零到上限', () async {
        await manager.loadChapter(0, initialCharOffset: 9999);

        expect(manager.currentCharOffset.value, lessThan(101));
      });

      test('加载失败设置 error 信号', () async {
        when(
          () => repo.loadChapterContent(
            any(),
            any(),
            readingMode: any(named: 'readingMode'),
          ),
        ).thenThrow(Exception('network error'));

        await manager.loadChapter(0);

        expect(manager.error.value, contains('操作失败，请稍后重试'));
        expect(manager.isLoading.value, false);
      });

      test('isFallback 时退化到 calculatePages', () async {
        // Override paginateChapter to return 0 (failure)
        _setupPaginateChapter(repo, isFallback: true);

        await manager.loadChapter(0);

        verify(
          () => repo.calculatePages(
            bookId: any(named: 'bookId'),
            chapterId: any(named: 'chapterId'),
            fontSize: any(named: 'fontSize'),
            lineHeight: any(named: 'lineHeight'),
            width: any(named: 'width'),
            height: any(named: 'height'),
            padding: any(named: 'padding'),
          ),
        ).called(1);
      });

      test('onChapterLoaded 回调在分页完成后触发', () async {
        var called = false;
        await manager.loadChapter(
          0,
          onChapterLoaded: () async {
            called = true;
          },
        );
        expect(called, isTrue);
      });

      test('beginPaginate 调用前 calibration.value 已写入 signal', () async {
        // 重置 mock：捕获每次 beginPaginate 的 params
        final captured = <PaginationParams>[];
        _setupBeginPaginateCapturing(repo, captured);

        await manager.loadChapter(0);

        expect(captured, isNotEmpty, reason: 'beginPaginate should be called');
        final firstParams = captured.first;
        expect(
          firstParams.calibration,
          isNotNull,
          reason:
              'calibration must be set before beginPaginate so config '
              'carries CharWidthTable into the session entry',
        );
      });

      test(
        'loadChapter without intent triggers beginPaginate (firstSpine)',
        () async {
          await manager.loadChapter(0);

          verify(
            () => repo.loadChapterFirstSpine(any(), any()),
          ).called(1);
          verify(
            () => repo.beginPaginate(
              bookId: any(named: 'bookId'),
              chapterIndex: any(named: 'chapterIndex'),
              params: any(named: 'params'),
              maxChars: any(named: 'maxChars'),
            ),
          ).called(1);
        },
      );
    });

    group('loadChapter 竞态', () {
      test('快速连续换章最终以最后一章为准', () async {
        var callbackCount = 0;

        when(() => repo.loadChapterFirstSpine(any(), any())).thenAnswer((
          invocation,
        ) async {
          final chapterIndex = invocation.positionalArguments[1] as int;
          return 'C' * (chapterIndex + 1) * 10;
        });

        final first = manager.loadChapter(
          0,
          onChapterLoaded: () async {
            callbackCount++;
          },
        );
        final second = manager.loadChapter(
          1,
          onChapterLoaded: () async {
            callbackCount++;
          },
        );
        await Future.wait([first, second]);

        expect(manager.chapterIndex.value, 1);
        expect(callbackCount, 1);
        expect(manager.loadPhase.value, ChapterLoadPhase.idle);
      });

      test('partial 分页延迟期间新 load 不覆盖信号', () async {
        final partialGate = Completer<void>();

        when(
          () => repo.beginPaginate(
            bookId: any(named: 'bookId'),
            chapterIndex: any(named: 'chapterIndex'),
            params: any(named: 'params'),
            maxChars: any(named: 'maxChars'),
          ),
        ).thenAnswer((invocation) async {
          final chapterIndex = invocation.namedArguments[#chapterIndex] as int;
          if (chapterIndex == 0) {
            await partialGate.future;
            return (totalPages: 99, isPartial: false);
          }
          return (totalPages: 2, isPartial: false);
        });

        when(() => repo.loadChapterFirstSpine(any(), any())).thenAnswer((
          invocation,
        ) async {
          final chapterIndex = invocation.positionalArguments[1] as int;
          return 'A' * (100 + chapterIndex);
        });

        final load0 = manager.loadChapter(0);
        await Future<void>.delayed(Duration.zero);
        final load1 = manager.loadChapter(1);
        await load1;
        partialGate.complete();
        await load0;

        expect(manager.chapterIndex.value, 1);
        expect(manager.totalPages.value, 2);
        expect(manager.loadPhase.value, ChapterLoadPhase.idle);
      });
    });

    // ==================== 章节导航 ====================

    group('章节导航', () {
      setUp(() async {
        when(
          () => repo.getChapters(any()),
        ).thenAnswer((_) async => createTestChapters(count: 5));
        await manager.loadChapters();
      });

      test('previousChapter 在第一章时不移动', () async {
        manager.chapterIndex.value = 0;
        await manager.previousChapter();
        expect(manager.chapterIndex.value, 0);
      });

      test('previousChapter 从第2章移动到第1章', () async {
        manager.chapterIndex.value = 1;
        await manager.previousChapter();
        expect(manager.chapterIndex.value, 0);
      });

      test('nextChapter 在最后一章时不移动', () async {
        manager.chapterIndex.value = 4;
        await manager.nextChapter();
        expect(manager.chapterIndex.value, 4);
      });

      test('nextChapter 从第0章移动到第1章', () async {
        manager.chapterIndex.value = 0;
        await manager.nextChapter();
        expect(manager.chapterIndex.value, 1);
      });

      test('jumpToChapter 跳转到指定章节', () async {
        await manager.jumpToChapter(3);
        expect(manager.chapterIndex.value, 3);
      });

      test('jumpToPosition 跳转到指定章节和偏移', () async {
        await manager.jumpToPosition(2, 42);
        expect(manager.chapterIndex.value, 2);
        expect(manager.currentCharOffset.value, 42);
      });
    });

    // ==================== 页面导航 ====================

    group('页面导航', () {
      setUp(() async {
        await manager.loadChapter(0);
      });

      test('previousPage 在第一页时不移动', () {
        expect(manager.pageIndex.value, 0);
        manager.previousPage();
        expect(manager.pageIndex.value, 0);
      });

      test('previousPage 从第2页移动到第1页', () {
        manager.pageIndex.value = 1;
        manager.previousPage();
        expect(manager.pageIndex.value, 0);
      });

      test('nextPage 在最后一页时不移动', () {
        manager.pageIndex.value = 1;
        manager.nextPage();
        expect(manager.pageIndex.value, 1);
      });

      test('nextPage 从第0页移动到第1页', () {
        manager.pageIndex.value = 0;
        manager.nextPage();
        expect(manager.pageIndex.value, 1);
      });

      test('loadPage 按页码加载并更新偏移', () {
        when(() => repo.descriptors).thenReturn([
          const PageDescriptor(
            pageIndex: 0,
            startOffset: 0,
            endOffset: 50,
            isLastPage: false,
          ),
          const PageDescriptor(
            pageIndex: 1,
            startOffset: 50,
            endOffset: 100,
            isLastPage: true,
          ),
        ]);

        manager.loadPage(1);

        expect(manager.pageIndex.value, 1);
        expect(manager.currentCharOffset.value, 50);
      });

      test('loadPage 越界时忽略', () {
        manager.loadPage(99);
        expect(manager.pageIndex.value, 0);
      });
    });

    // ==================== resolvePageIndexFromPageInfo ====================

    group('resolvePageIndexFromPageInfo', () {
      test('空列表返回 0', () {
        expect(PaginationEngine.resolvePageIndexFromPageInfo([], 50), 0);
      });

      test('offset 落在第0页范围内', () {
        final pages = [
          PageInfo(
            pageIndex: 0,
            content: 'A' * 50,
            startOffset: 0,
            endOffset: 50,
          ),
        ];
        expect(PaginationEngine.resolvePageIndexFromPageInfo(pages, 25), 0);
      });

      test('offset 落在第1页范围内', () {
        final pages = [
          PageInfo(
            pageIndex: 0,
            content: 'A' * 50,
            startOffset: 0,
            endOffset: 50,
          ),
          PageInfo(
            pageIndex: 1,
            content: 'A' * 50,
            startOffset: 50,
            endOffset: 100,
          ),
        ];
        expect(PaginationEngine.resolvePageIndexFromPageInfo(pages, 75), 1);
      });

      test('offset 超范围时返回最后一页', () {
        final pages = [
          PageInfo(
            pageIndex: 0,
            content: 'A' * 50,
            startOffset: 0,
            endOffset: 50,
          ),
          PageInfo(
            pageIndex: 1,
            content: 'A' * 50,
            startOffset: 50,
            endOffset: 100,
          ),
        ];
        expect(PaginationEngine.resolvePageIndexFromPageInfo(pages, 999), 1);
      });
    });

    // ==================== resolvePageIndexForOffset (descriptors) ====================

    group('resolvePageIndexForOffset', () {
      test('空列表返回 0', () {
        expect(
          PaginationEngine.resolvePageIndexForOffset(<PageDescriptor>[], 50),
          0,
        );
      });

      test('offset 落在第0页范围内', () {
        final descriptors = [
          const PageDescriptor(
            pageIndex: 0,
            startOffset: 0,
            endOffset: 50,
            isLastPage: false,
          ),
        ];
        expect(PaginationEngine.resolvePageIndexForOffset(descriptors, 25), 0);
      });

      test('offset 落在第1页范围内', () {
        final descriptors = [
          const PageDescriptor(
            pageIndex: 0,
            startOffset: 0,
            endOffset: 50,
            isLastPage: false,
          ),
          const PageDescriptor(
            pageIndex: 1,
            startOffset: 50,
            endOffset: 100,
            isLastPage: true,
          ),
        ];
        expect(PaginationEngine.resolvePageIndexForOffset(descriptors, 75), 1);
      });

      test('offset 超范围时返回最后一页', () {
        final descriptors = [
          const PageDescriptor(
            pageIndex: 0,
            startOffset: 0,
            endOffset: 50,
            isLastPage: false,
          ),
          const PageDescriptor(
            pageIndex: 1,
            startOffset: 50,
            endOffset: 100,
            isLastPage: true,
          ),
        ];
        expect(PaginationEngine.resolvePageIndexForOffset(descriptors, 999), 1);
      });
    });

    // ==================== 计算信号 ====================

    group('计算信号', () {
      test('progressText 显示章节百分比', () async {
        when(
          () => repo.getChapters(any()),
        ).thenAnswer((_) async => createTestChapters(count: 5));
        await manager.loadChapters();

        manager.chapterIndex.value = 1; // 2/5 = 40.0%
        expect(manager.progressText.value, contains('40.0%'));
      });

      test('progressText 在无章节时显示 0%', () {
        expect(manager.progressText.value, '0%');
      });

      test('currentChapterTitle 返回当前章节标题', () async {
        when(
          () => repo.getChapters(any()),
        ).thenAnswer((_) async => createTestChapters(count: 3));
        await manager.loadChapters();

        manager.chapterIndex.value = 1;
        expect(manager.currentChapterTitle.value, '第2章');
      });

      test('currentChapterTitle 在无章节时显示占位符', () {
        expect(manager.currentChapterTitle.value, '');
      });
    });

    // ==================== reset ====================

    group('reset', () {
      setUp(() async {
        manager.bookId.value = 'book_1';
        await manager.loadChapters();
        await manager.loadChapter(0);
      });

      test('重置所有信号到默认值', () {
        manager.reset();

        expect(manager.bookId.value, '0');
        expect(manager.chapterIndex.value, 0);
        expect(manager.totalPages.value, 0);
        expect(manager.pageIndex.value, 0);
        expect(manager.currentCharOffset.value, 0);
        expect(manager.pendingJumpCharOffset.value, null);
        expect(manager.isLoading.value, false);
        expect(manager.error.value, null);
        expect(manager.loadPhase.value, ChapterLoadPhase.idle);
        expect(manager.autoScrollTick.value, 0);
      });

      test(
        'PR1+PR2 fix: chapterManager.bookId/chapterIndex 是 loadChapters 的查询源',
        () async {
          // 模拟 ReaderViewModel.initialize 的写入路径：写入 chapterManager，
          // 然后 loadChapters 必须用新值查询 _repo.getChapters(bookId: ...)
          manager.bookId.value = 'new_book_id';
          manager.chapterIndex.value = 5;
          manager.currentCharOffset.value = 1234;

          // 验证写入确实到了 ChapterViewModel 的 signals（PR1 迁入）
          expect(manager.bookId.value, 'new_book_id');
          expect(manager.chapterIndex.value, 5);
          expect(manager.currentCharOffset.value, 1234);

          // 验证 _repo.getChapters 是用 manager.bookId 调用的（PR1+PR2 修复的关键）
          await manager.loadChapters();
          verify(() => repo.getChapters('new_book_id')).called(1);
        },
      );
    });
  });
}
