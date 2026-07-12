// test/features/reader/core/application/chapter_load_orchestrator_test.dart
//
// 验证 ChapterLoadOrchestrator 核心行为：
// - generation gate：并发换章时旧请求被 stale/cancelled
// - resetPhase 机制
// - 错误处理与信号更新
//
// 注意：完整 pagination pipeline 测试依赖 Flutter SchedulerBinding（metrics
// backfeed），不适合纯单元测试。此处仅测试 scroll mode（不触发 Rust 分页）
// 和 generation gate 机制。
//
// ChapterViewModel 构造函数会创建大量内部依赖（ChapterLoader、ChapterNavigator
// 等），需要全面 stub repo。遗漏会导致 timeout。

import 'dart:async';
import 'dart:ui' show TextAlign;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/local/preferences_service.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/core/settings/persisted_signal.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_load_orchestrator.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_load_phase.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_load_request.dart';
import 'package:zephyr_reader/features/reader/core/data/next_chapter_staging.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_view_model.dart';
import 'package:zephyr_reader/features/reader/core/application/pagination_coordinator.dart';
import 'package:zephyr_reader/features/reader/core/domain/reader_repository_interface.dart';
import 'package:zephyr_reader/features/reader/data/pagination_params.dart';
import 'package:zephyr_reader/features/reader/data/typeset_calibrator.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_typography_defaults.dart';
import 'package:zephyr_reader/features/reader/domain/config/reading_mode_utils.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';
import 'package:zephyr_reader/src/rust/domain/types/typeset.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

import '../../../../helpers/fixtures.dart';

class _MockRepo extends Mock implements ReaderRepositoryInterface {}

class _MockPagination extends Mock implements PaginationCoordinator {}

class _MockPrefs extends Mock implements PreferencesService {
  _MockPrefs() {
    when(
      () => getDouble(any(), defaultValue: any(named: 'defaultValue')),
    ).thenAnswer((i) => i.namedArguments[#defaultValue] as double);
    when(
      () => getInt(any(), defaultValue: any(named: 'defaultValue')),
    ).thenAnswer((i) => i.namedArguments[#defaultValue] as int);
    when(
      () => getBool(any(), defaultValue: any(named: 'defaultValue')),
    ).thenAnswer((i) => i.namedArguments[#defaultValue] as bool);
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
  final prefs = _MockPrefs();
  @override
  late final fontSize = persistedDouble(prefs, '', 16.0);
  @override
  late final lineHeight = persistedDouble(prefs, '', 1.6);
  @override
  late final padding = persistedDouble(
    prefs,
    '',
    ReaderTypographyDefaults.padding,
  );
  @override
  late final letterSpacing = persistedDouble(prefs, '', 0.0);
  @override
  late final paragraphSpacing = persistedDouble(
    prefs,
    '',
    ReaderTypographyDefaults.paragraphSpacing,
  );
  @override
  late final punctuationSqueeze = persistedBool(prefs, '', true);
  @override
  late final firstLineIndent = persistedBool(prefs, '', true);
  @override
  late final theme = persistedEnum<ReaderTheme>(
    prefs,
    '',
    ReaderTheme.light,
    ReaderTheme.fromId,
  );
  @override
  late final readerBgColorIndex = persistedInt(prefs, '', 0);
  @override
  late final autoScroll = persistedBool(prefs, '', false);
  @override
  late final autoScrollSpeed = persistedInt(prefs, '', 30);
  @override
  late final baselineAlign = persistedBool(prefs, '', true);
  @override
  late final language = persistedEnum<LanguageType>(
    prefs,
    '',
    LanguageType.auto,
    (n) => LanguageType.values.firstWhere(
      (e) => e.name == n,
      orElse: () => LanguageType.auto,
    ),
  );
  @override
  late final autoSpaceRatio = persistedDouble(prefs, '', 0.25);
  @override
  late final textAlign = persistedEnum(
    prefs,
    '',
    TextAlign.justify,
    (n) => TextAlign.values.firstWhere(
      (e) => e.name == n,
      orElse: () => TextAlign.justify,
    ),
  );
  @override
  late final paginationSkin = persistedEnum(
    prefs,
    '',
    PaginationSkin.slide,
    (n) => PaginationSkin.values.firstWhere(
      (e) => e.name == n,
      orElse: () => PaginationSkin.slide,
    ),
  );
  @override
  late final tapLayout = persistedEnum(
    prefs,
    '',
    TapLayout.rightHanded,
    (n) => TapLayout.values.firstWhere(
      (e) => e.name == n,
      orElse: () => TapLayout.rightHanded,
    ),
  );
  @override
  late final followSystemFontScale = persistedBool(prefs, '', false);
  @override
  final brightnessOverlay = signal<double>(0.0);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _desc3 = [
  PageDescriptor(
    pageIndex: 0,
    startOffset: 0,
    endOffset: 99,
    isLastPage: false,
    firstParagraphIndex: 0,
    lastParagraphIndex: 0,
  ),
  PageDescriptor(
    pageIndex: 1,
    startOffset: 100,
    endOffset: 199,
    isLastPage: false,
    firstParagraphIndex: 1,
    lastParagraphIndex: 1,
  ),
  PageDescriptor(
    pageIndex: 2,
    startOffset: 200,
    endOffset: 300,
    isLastPage: true,
    firstParagraphIndex: 2,
    lastParagraphIndex: 2,
  ),
];

void main() {
  setUpAll(() {
    registerFallbackValue(
      const PaginationParams(
        fontSize: 16,
        lineHeight: 1.6,
        width: 400,
        height: 600,
        padding: 20,
      ),
    );
  });

  late _MockRepo repo;
  late _MockPagination pagination;
  late _MockConfig config;
  late ChapterViewModel chapterVM;
  late AsyncSignal<List<Chapter>> chapters;
  late Signal<int> totalPages;
  late Signal<int> pageIndex;
  late Signal<bool> isLoading;
  late Signal<String?> error;
  late Signal<ChapterLoadPhase> loadPhase;
  late ChapterLoadOrchestrator orchestrator;

  setUp(() {
    repo = _MockRepo();
    pagination = _MockPagination();
    config = _MockConfig();
    if (!getIt.isRegistered<PreferencesService>()) {
      getIt.registerSingleton<PreferencesService>(_MockPrefs());
    }
    _stubAllRepo(repo);

    chapterVM = ChapterViewModel(repo, config);

    chapters = asyncSignal<List<Chapter>>(
      AsyncState.data([createTestChapter()]),
    );
    totalPages = signal<int>(0);
    pageIndex = signal<int>(0);
    isLoading = signal<bool>(false);
    error = signal<String?>(null);
    loadPhase = signal<ChapterLoadPhase>(ChapterLoadPhase.idle);

    orchestrator = ChapterLoadOrchestrator(
      contentRepo: repo,
      chapterVM: chapterVM,
      pagination: pagination,
      chapters: chapters,
      totalPages: totalPages,
      pageIndex: pageIndex,
      isLoading: isLoading,
      error: error,
      loadPhase: loadPhase,
    );

    when(
      () => pagination.calibration,
    ).thenReturn(signal<CalibrationData?>(null));
    when(() => pagination.computeConfigHash()).thenReturn(BigInt.from(12345));
    when(
      () => pagination.paginateFirstScreen(any()),
    ).thenAnswer((_) async => const (totalPages: 3, isPartial: true));
    when(
      () => pagination.expandToFullChapter(any()),
    ).thenAnswer((_) async => 3);
    when(() => pagination.isPaginationValid(any())).thenReturn(true);
    when(
      () => pagination.applyFullResult(
        total: any(named: 'total'),
        initialCharOffset: any(named: 'initialCharOffset'),
        content: any(named: 'content'),
      ),
    ).thenReturn(const (totalPages: 3, pageIndex: 0));
    when(() => pagination.resolvePageForCharOffset(any(), any())).thenReturn(0);
    when(() => pagination.devicePixelRatio).thenReturn(1.0);
    when(() => pagination.fontFamily).thenReturn('Noto Sans SC');
    when(() => pagination.pageWidth).thenReturn(400);
    when(() => pagination.pageHeight).thenReturn(600);
  });

  group('generation gate', () {
    test('resetPhase sets idle', () {
      loadPhase.value = ChapterLoadPhase.failed;
      orchestrator.resetPhase();
      expect(loadPhase.value, ChapterLoadPhase.idle);
    });

    test('second scroll run supersedes first — isLoading ends false', () async {
      when(
        () => repo.loadChapterContent(
          any(),
          any(),
          readingMode: any(named: 'readingMode'),
        ),
      ).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return 'slow';
      });
      unawaited(
        orchestrator.run(
          const ChapterLoadRequest(
            chapterIndex: 0,
            readingMode: ReadingMode.scroll,
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      when(
        () => repo.loadChapterContent(
          any(),
          any(),
          readingMode: any(named: 'readingMode'),
        ),
      ).thenAnswer((_) async => 'fast');
      await orchestrator.run(
        const ChapterLoadRequest(
          chapterIndex: 1,
          readingMode: ReadingMode.scroll,
        ),
      );
      expect(isLoading.value, isFalse);
    });
  });

  group('scroll mode', () {
    test('sets content without calling pagination methods', () async {
      await orchestrator.run(
        const ChapterLoadRequest(
          chapterIndex: 0,
          readingMode: ReadingMode.scroll,
        ),
      );
      verifyNever(() => pagination.paginateFirstScreen(any()));
      verifyNever(() => pagination.expandToFullChapter(any()));
      expect(chapterVM.chapterContent.value.hasValue, isTrue);
      expect(loadPhase.value, ChapterLoadPhase.idle);
      expect(isLoading.value, isFalse);
      expect(totalPages.value, 1);
    });
  });

  group('error handling', () {
    test('loadChapterContent failure → failed phase + error', () async {
      when(
        () => repo.loadChapterContent(
          any(),
          any(),
          readingMode: any(named: 'readingMode'),
        ),
      ).thenThrow(Exception('disk error'));
      await orchestrator.run(
        const ChapterLoadRequest(
          chapterIndex: 0,
          readingMode: ReadingMode.scroll,
        ),
      );
      expect(error.value, isNotNull);
      expect(loadPhase.value, ChapterLoadPhase.failed);
      expect(isLoading.value, isFalse);
    });
  });

  group('staging promote', () {
    test(
      'I2: staging promote forward sets correct pagination signals',
      () async {
        final staging = NextChapterStaging(
          chapterIndex: 1,
          configHash: BigInt.from(12345),
          descriptors: _desc3,
          firstPageContent: 'staging page 0',
          isPartial: false,
          paginationMode: ChapterPaginationMode.contentBlocks,
        );
        when(() => repo.nextChapterStaging).thenReturn(staging);
        when(
          () => pagination.paginateFirstScreenFromCache(any()),
        ).thenAnswer((_) async => const (totalPages: 3, isPartial: false));

        await orchestrator.run(
          const ChapterLoadRequest(
            chapterIndex: 1,
            navigationKind: ChapterNavigationKind.adjacentCrossChapter,
          ),
        );

        expect(totalPages.value, 3);
        expect(chapterVM.chapterIndex.value, 1);
        expect(pageIndex.value, 0);
        expect(isLoading.value, isFalse);
        expect(error.value, isNull);
        expect(loadPhase.value, ChapterLoadPhase.idle);
      },
    );

    test('I2: staging promote failure protects visible content', () async {
      // Pre-set chapter 0 content (simulate already-loaded state,
      // avoiding pagination pipeline which requires SchedulerBinding)
      chapterVM.chapterContent.value = AsyncState.data('chapter 0 content');
      chapterVM.chapterIndex.value = 0;

      // Staging for chapter 1 with failure
      final staging = NextChapterStaging(
        chapterIndex: 1,
        configHash: BigInt.from(12345),
        descriptors: _desc3,
        firstPageContent: 'staging page 0',
        isPartial: false,
        paginationMode: ChapterPaginationMode.contentBlocks,
      );
      when(() => repo.nextChapterStaging).thenReturn(staging);
      when(
        () => pagination.paginateFirstScreenFromCache(any()),
      ).thenThrow(Exception('staging failed'));

      await orchestrator.run(
        const ChapterLoadRequest(
          chapterIndex: 1,
          navigationKind: ChapterNavigationKind.adjacentCrossChapter,
        ),
      );

      expect(chapterVM.chapterContent.value.value, 'chapter 0 content');
      expect(chapterVM.chapterContent.value.hasValue, isTrue);
      expect(error.value, isNull);
    });
  });
}

void _stubAllRepo(_MockRepo repo) {
  when(() => repo.clearAdjacentStaging()).thenReturn(null);
  when(
    () => repo.loadChapterContent(
      any(),
      any(),
      readingMode: any(named: 'readingMode'),
    ),
  ).thenAnswer((_) async => 'test content');
  when(() => repo.disposePagination()).thenReturn(null);
  when(() => repo.descriptors).thenReturn(_desc3);
  when(() => repo.sessionIsPartial).thenReturn(false);
  when(() => repo.sessionConfigHash).thenReturn(null);
  when(() => repo.sessionChapterIndex).thenReturn(null);
  when(() => repo.sessionMode).thenReturn(ChapterPaginationMode.plainText);
  when(() => repo.sessionFilePath).thenReturn('/tmp/ch0.txt');
  when(() => repo.nextChapterStaging).thenReturn(null);
  when(() => repo.prevChapterStaging).thenReturn(null);
  when(() => repo.consumeEpubRichSkippedNotice()).thenReturn(false);
  when(() => repo.ensurePageWindow(any())).thenReturn(null);
  when(() => repo.resolvePageIndexForCharOffset(any())).thenReturn(null);
  when(() => repo.currentRichContent).thenReturn(null);
  when(() => repo.currentRichParagraphs).thenReturn(null);
  when(() => repo.currentChapterIr).thenReturn(null);
  when(() => repo.currentChapterFilePath).thenReturn(null);
  when(() => repo.preloadGeneration).thenReturn(ValueNotifier<int>(0));
  when(
    () => repo.getChapters(any()),
  ).thenAnswer((_) async => [createTestChapter()]);
  when(() => repo.loadReadingProgress(any())).thenAnswer((_) async => null);
  when(
    () => repo.beginPaginate(
      bookId: any(named: 'bookId'),
      chapterIndex: any(named: 'chapterIndex'),
      params: any(named: 'params'),
      maxChars: any(named: 'maxChars'),
    ),
  ).thenAnswer((_) async => const (totalPages: 3, isPartial: true));
  when(
    () => repo.beginPaginateFromCache(
      bookId: any(named: 'bookId'),
      chapterIndex: any(named: 'chapterIndex'),
      params: any(named: 'params'),
      maxChars: any(named: 'maxChars'),
    ),
  ).thenAnswer((_) async => const (totalPages: 3, isPartial: true));
  when(
    () => repo.repaginateInPlace(
      bookId: any(named: 'bookId'),
      chapterIndex: any(named: 'chapterIndex'),
      params: any(named: 'params'),
      maxChars: any(named: 'maxChars'),
    ),
  ).thenAnswer((_) async => const (totalPages: 3, isPartial: true));
  when(
    () => repo.expandToFullChapter(
      bookId: any(named: 'bookId'),
      chapterIndex: any(named: 'chapterIndex'),
      params: any(named: 'params'),
    ),
  ).thenAnswer((_) async => const (totalPages: 3, isPartial: false));
  when(() => repo.fetchPageContent(any())).thenAnswer((_) async => 'page text');
  when(() => repo.preloadChapter(any(), any())).thenAnswer((_) async {});
  when(() => repo.syncChapterTypesetLayout(any())).thenReturn(null);
  when(() => repo.warmPageCache(any(), any())).thenReturn(null);
  when(
    () => repo.preloadPreviousChapterStaging(any(), any()),
  ).thenAnswer((_) async {});
  when(
    () => repo.preloadNextChapterStaging(any(), any()),
  ).thenAnswer((_) async {});
  when(() => repo.clearNextChapterStaging()).thenReturn(null);
  when(
    () => repo.loadScrollSegment(
      any(),
      any(),
      readingMode: any(named: 'readingMode'),
    ),
  ).thenAnswer(
    (_) async => (
      content: 'scroll',
      richParagraphs: null,
      richRootSpan: null,
      epubRichSkipped: false,
      chapterIr: null,
      chapterFilePath: null,
    ),
  );
}
