import 'dart:async';
import 'dart:convert';
import 'package:flureadium/flureadium.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zephyr_reader/core/reading/config/reader_config.dart';
import 'package:zephyr_reader/core/settings/persisted_signal.dart';
import 'package:zephyr_reader/features/reader/epub/readium_view_model.dart';
import 'package:zephyr_reader/src/rust/domain/engine_positions/models.dart';
import 'package:zephyr_reader/src/rust/domain/progress/models.dart';

class _MockFlureadium extends Mock implements Flureadium {}

class _MockReaderConfig extends Mock implements ReaderConfig {}

class _MockPersistedSignal<T> extends Mock implements PersistedSignal<T> {}

class _FakeEpubPreferences extends Fake implements EPUBPreferences {}

class _FakeNavigationConfig extends Fake implements ReaderNavigationConfig {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEpubPreferences());
    registerFallbackValue(_FakeNavigationConfig());
  });


  test('waits for the native viewport before applying preferences', () async {
    final reader = _MockFlureadium();
    final config = _MockReaderConfig();
    final theme = _MockPersistedSignal<ReaderTheme>();
    final fontSize = _MockPersistedSignal<double>();
    final padding = _MockPersistedSignal<double>();
    final publication = Publication(
      metadata: Metadata(
        localizedTitle: LocalizedString.fromString('Test Book'),
      ),
      readingOrder: [
        const Link(href: 'chapter.xhtml', type: 'application/xhtml+xml'),
      ],
    );

    when(() => config.theme).thenReturn(theme);
    when(() => theme.value).thenReturn(ReaderTheme.light);
    when(() => config.fontSize).thenReturn(fontSize);
    // Legacy Builtin configuration used 18dp. Readium interprets the same
    // numeric value as 18%, which renders the book as a tiny center column.
    when(() => fontSize.value).thenReturn(18.0);
    when(() => config.padding).thenReturn(padding);
    when(() => padding.value).thenReturn(24.0);
    final fontFamily = _MockPersistedSignal<String>();
    when(() => config.fontFamily).thenReturn(fontFamily);
    when(() => fontFamily.value).thenReturn('System');
    final bgIndex = _MockPersistedSignal<int>();
    when(() => config.readerBgColorIndex).thenReturn(bgIndex);
    when(() => bgIndex.value).thenReturn(0);
    when(
      () => reader.openPublication(any()),
    ).thenAnswer((_) async => publication);
    when(
      () => reader.onReaderStatusChanged,
    ).thenAnswer((_) => const Stream.empty());
    when(() => reader.onErrorEvent).thenAnswer((_) => const Stream.empty());
    when(() => reader.setEPUBPreferences(any())).thenAnswer((_) async {});
    when(() => reader.setNavigationConfig(any())).thenAnswer((_) async {});
    when(() => reader.closePublication()).thenAnswer((_) async {});

    final vm = ReadiumViewModel(
      config: config,
      bookId: 'book-1',
      reader: reader,
    );

    await vm.open('book.epub');

    expect(vm.status.value, 'opening...');
    verifyNever(() => reader.setEPUBPreferences(any()));

    await vm.onViewportReady();

    expect(vm.status.value, 'ready');
    final capturedPreferences =
        verify(() => reader.setEPUBPreferences(captureAny())).captured.single
            as EPUBPreferences;
    expect(capturedPreferences.fontSize, 100);
    // ReaderConfig stores the legacy UI value where 20 is the default.
    // Readium expects a multiplier where 1.0 is the default margin.
    expect(capturedPreferences.pageMargins, 1.2);
    expect(capturedPreferences.verticalScroll, isFalse);
    final navigationConfig =
        verify(() => reader.setNavigationConfig(captureAny())).captured.single
            as ReaderNavigationConfig;
    expect(navigationConfig.enableSwipeNavigation, isFalse);

    await vm.setReadingMode(ReadingMode.scroll);
    final scrollPreferences =
        verify(() => reader.setEPUBPreferences(captureAny())).captured.single
            as EPUBPreferences;
    expect(scrollPreferences.verticalScroll, isTrue);

    await vm.close();
    await vm.close();
    verify(() => reader.closePublication()).called(1);
  });

  test('closes a publication that finishes opening after page exit', () async {
    final reader = _MockFlureadium();
    final config = _MockReaderConfig();
    final openCompleter = Completer<Publication>();
    final publication = Publication(
      metadata: Metadata(
        localizedTitle: LocalizedString.fromString('Late Book'),
      ),
      readingOrder: [
        const Link(href: 'chapter.xhtml', type: 'application/xhtml+xml'),
      ],
    );

    when(
      () => reader.openPublication(any()),
    ).thenAnswer((_) => openCompleter.future);
    when(() => reader.closePublication()).thenAnswer((_) async {});

    final vm = ReadiumViewModel(
      config: config,
      bookId: 'book-2',
      reader: reader,
    );
    final openFuture = vm.open('late.epub');
    await untilCalled(() => reader.openPublication(any()));

    await vm.close();
    openCompleter.complete(publication);

    await expectLater(openFuture, throwsStateError);
    verify(() => reader.closePublication()).called(1);
    expect(vm.status.value, 'closed');
  });

  test('next page does not skip chapter when locator advances', () async {
    final reader = _MockFlureadium();
    final config = _MockReaderConfig();
    final theme = _MockPersistedSignal<ReaderTheme>();
    final fontSize = _MockPersistedSignal<double>();
    final padding = _MockPersistedSignal<double>();
    final publication = Publication(
      metadata: Metadata(
        localizedTitle: LocalizedString.fromString('Test Book'),
      ),
      readingOrder: [
        const Link(href: 'chapter.xhtml', type: 'application/xhtml+xml'),
      ],
    );
    late ReadiumViewModel vm;

    when(() => config.theme).thenReturn(theme);
    when(() => theme.value).thenReturn(ReaderTheme.light);
    when(() => config.fontSize).thenReturn(fontSize);
    when(() => fontSize.value).thenReturn(100);
    when(() => config.padding).thenReturn(padding);
    when(() => padding.value).thenReturn(20);
    final fontFamily = _MockPersistedSignal<String>();
    when(() => config.fontFamily).thenReturn(fontFamily);
    when(() => fontFamily.value).thenReturn('System');
    final bgIndex = _MockPersistedSignal<int>();
    when(() => config.readerBgColorIndex).thenReturn(bgIndex);
    when(() => bgIndex.value).thenReturn(0);
    when(
      () => reader.openPublication(any()),
    ).thenAnswer((_) async => publication);
    when(
      () => reader.onReaderStatusChanged,
    ).thenAnswer((_) => const Stream.empty());
    when(() => reader.onErrorEvent).thenAnswer((_) => const Stream.empty());
    when(() => reader.setEPUBPreferences(any())).thenAnswer((_) async {});
    when(() => reader.setNavigationConfig(any())).thenAnswer((_) async {});
    when(() => reader.goRight()).thenAnswer((_) async {
      scheduleMicrotask(
        () => vm.onLocatorChanged(
          const Locator(href: 'chapter.xhtml', type: 'application/xhtml+xml'),
        ),
      );
    });
    when(() => reader.skipToNext()).thenAnswer((_) async {});

    vm = ReadiumViewModel(
      config: config,
      bookId: 'book-next-page',
      reader: reader,
    );
    await vm.open('book.epub');
    await vm.onViewportReady();

    await vm.goRight();

    verify(() => reader.goRight()).called(1);
    verifyNever(() => reader.skipToNext());
  });

  test(
    'next page does not infer a chapter fallback from a missing locator event',
    () async {
      final reader = _MockFlureadium();
      final config = _MockReaderConfig();
      final theme = _MockPersistedSignal<ReaderTheme>();
      final fontSize = _MockPersistedSignal<double>();
      final padding = _MockPersistedSignal<double>();
      final publication = Publication(
        metadata: Metadata(
          localizedTitle: LocalizedString.fromString('Test Book'),
        ),
        readingOrder: [
          const Link(href: 'chapter-1.xhtml', type: 'application/xhtml+xml'),
          const Link(href: 'chapter-2.xhtml', type: 'application/xhtml+xml'),
        ],
      );

      when(() => config.theme).thenReturn(theme);
      when(() => theme.value).thenReturn(ReaderTheme.light);
      when(() => config.fontSize).thenReturn(fontSize);
      when(() => fontSize.value).thenReturn(100);
      when(() => config.padding).thenReturn(padding);
    when(() => padding.value).thenReturn(20);
    final fontFamily = _MockPersistedSignal<String>();
    when(() => config.fontFamily).thenReturn(fontFamily);
    when(() => fontFamily.value).thenReturn('System');
    final bgIndex = _MockPersistedSignal<int>();
    when(() => config.readerBgColorIndex).thenReturn(bgIndex);
    when(() => bgIndex.value).thenReturn(0);
      when(
        () => reader.openPublication(any()),
      ).thenAnswer((_) async => publication);
      when(
        () => reader.onReaderStatusChanged,
      ).thenAnswer((_) => const Stream.empty());
      when(() => reader.onErrorEvent).thenAnswer((_) => const Stream.empty());
      when(() => reader.setEPUBPreferences(any())).thenAnswer((_) async {});
      when(() => reader.setNavigationConfig(any())).thenAnswer((_) async {});
      when(() => reader.goRight()).thenAnswer((_) async {});
      when(() => reader.skipToNext()).thenAnswer((_) async {});

      final vm = ReadiumViewModel(
        config: config,
        bookId: 'book-next-chapter',
        reader: reader,
      );
      await vm.open('book.epub');
      await vm.onViewportReady();

      await vm.goRight();

      verify(() => reader.goRight()).called(1);
      verifyNever(() => reader.skipToNext());
    },
  );

  test('scroll boundary advances only after the resource end', () async {
    final reader = _MockFlureadium();
    final config = _MockReaderConfig();
    final theme = _MockPersistedSignal<ReaderTheme>();
    final fontSize = _MockPersistedSignal<double>();
    final padding = _MockPersistedSignal<double>();
    final publication = Publication(
      metadata: Metadata(
        localizedTitle: LocalizedString.fromString('Test Book'),
      ),
      readingOrder: [
        const Link(href: 'chapter-1.xhtml', type: 'application/xhtml+xml'),
        const Link(href: 'chapter-2.xhtml', type: 'application/xhtml+xml'),
      ],
    );

    when(() => config.theme).thenReturn(theme);
    when(() => theme.value).thenReturn(ReaderTheme.light);
    when(() => config.fontSize).thenReturn(fontSize);
    when(() => fontSize.value).thenReturn(100);
    when(() => config.padding).thenReturn(padding);
    when(() => padding.value).thenReturn(20);
    final fontFamily = _MockPersistedSignal<String>();
    when(() => config.fontFamily).thenReturn(fontFamily);
    when(() => fontFamily.value).thenReturn('System');
    final bgIndex = _MockPersistedSignal<int>();
    when(() => config.readerBgColorIndex).thenReturn(bgIndex);
    when(() => bgIndex.value).thenReturn(0);
    when(
      () => reader.openPublication(any()),
    ).thenAnswer((_) async => publication);
    when(
      () => reader.onReaderStatusChanged,
    ).thenAnswer((_) => const Stream.empty());
    when(() => reader.onErrorEvent).thenAnswer((_) => const Stream.empty());
    when(() => reader.setEPUBPreferences(any())).thenAnswer((_) async {});
    when(() => reader.setNavigationConfig(any())).thenAnswer((_) async {});
    when(() => reader.skipToNext()).thenAnswer((_) async {});

    final vm = ReadiumViewModel(
      config: config,
      bookId: 'book-scroll-boundary',
      reader: reader,
    );
    await vm.open('book.epub');
    await vm.onViewportReady();
    await vm.setReadingMode(ReadingMode.scroll);

    vm.onLocatorChanged(
      const Locator(
        href: 'chapter-1.xhtml',
        type: 'application/xhtml+xml',
        locations: Locations(progression: 0.8),
      ),
    );
    await vm.advanceFromScrollBoundary();
    verifyNever(() => reader.skipToNext());

    vm.onLocatorChanged(
      const Locator(
        href: 'chapter-1.xhtml',
        type: 'application/xhtml+xml',
        locations: Locations(progression: 1),
      ),
    );
    await vm.advanceFromScrollBoundary();
    verify(() => reader.skipToNext()).called(1);
  });

  test('pagination never advances through the scroll boundary hook', () async {
    final reader = _MockFlureadium();
    final config = _MockReaderConfig();
    final publication = Publication(
      metadata: Metadata(
        localizedTitle: LocalizedString.fromString('Test Book'),
      ),
      readingOrder: [
        const Link(href: 'chapter-1.xhtml', type: 'application/xhtml+xml'),
        const Link(href: 'chapter-2.xhtml', type: 'application/xhtml+xml'),
      ],
    );

    when(
      () => reader.openPublication(any()),
    ).thenAnswer((_) async => publication);
    when(() => reader.skipToNext()).thenAnswer((_) async {});

    final vm = ReadiumViewModel(
      config: config,
      bookId: 'book-pagination-boundary',
      reader: reader,
    );
    await vm.open('book.epub');
    vm.onLocatorChanged(
      const Locator(
        href: 'chapter-1.xhtml',
        type: 'application/xhtml+xml',
        locations: Locations(progression: 1),
      ),
    );

    await vm.advanceFromScrollBoundary();
    verifyNever(() => reader.skipToNext());
  });

  test('finalizes reading sessions on chapter change and close', () async {
    final reader = _MockFlureadium();
    final config = _MockReaderConfig();
    final theme = _MockPersistedSignal<ReaderTheme>();
    final fontSize = _MockPersistedSignal<double>();
    final padding = _MockPersistedSignal<double>();
    final fontFamily = _MockPersistedSignal<String>();
    final bgIndex = _MockPersistedSignal<int>();
    final publication = Publication(
      metadata: Metadata(
        localizedTitle: LocalizedString.fromString('Test Book'),
      ),
      readingOrder: [
        const Link(href: 'chapter-1.xhtml', type: 'application/xhtml+xml'),
        const Link(href: 'chapter-2.xhtml', type: 'application/xhtml+xml'),
      ],
      tableOfContents: [
        const Link(
          href: 'chapter-1.xhtml',
          type: 'application/xhtml+xml',
          title: 'Chapter 1',
        ),
        const Link(
          href: 'chapter-2.xhtml',
          type: 'application/xhtml+xml',
          title: 'Chapter 2',
        ),
      ],
    );

    when(() => config.theme).thenReturn(theme);
    when(() => theme.value).thenReturn(ReaderTheme.light);
    when(() => config.fontSize).thenReturn(fontSize);
    when(() => fontSize.value).thenReturn(100);
    when(() => config.padding).thenReturn(padding);
    when(() => padding.value).thenReturn(20);
    when(() => config.fontFamily).thenReturn(fontFamily);
    when(() => fontFamily.value).thenReturn('System');
    when(() => config.readerBgColorIndex).thenReturn(bgIndex);
    when(() => bgIndex.value).thenReturn(0);
    when(
      () => reader.openPublication(any()),
    ).thenAnswer((_) async => publication);
    when(() => reader.onReaderStatusChanged)
        .thenAnswer((_) => const Stream.empty());
    when(() => reader.onErrorEvent).thenAnswer((_) => const Stream.empty());
    when(() => reader.setEPUBPreferences(any())).thenAnswer((_) async {});
    when(() => reader.setNavigationConfig(any())).thenAnswer((_) async {});
    when(() => reader.closePublication()).thenAnswer((_) async {});

    final recorded = <({int chapterIndex, int startOffset, int endOffset})>[];
    final vm = ReadiumViewModel(
      config: config,
      bookId: 'book-sessions',
      reader: reader,
      sessionRecorder: ({
        required bookId,
        required chapterIndex,
        required startCharOffset,
        required endCharOffset,
        required startedAt,
      }) async {
        recorded.add(
          (
            chapterIndex: chapterIndex,
            startOffset: startCharOffset,
            endOffset: endCharOffset,
          ),
        );
      },
    );

    await vm.open('book.epub');
    await vm.onViewportReady();
    vm.onLocatorChanged(
      const Locator(
        href: 'chapter-1.xhtml',
        type: 'application/xhtml+xml',
        locations: Locations(position: 10, totalProgression: 0.05),
      ),
    );
    vm.onLocatorChanged(
      const Locator(
        href: 'chapter-2.xhtml',
        type: 'application/xhtml+xml',
        locations: Locations(position: 12, totalProgression: 0.06),
      ),
    );
    await vm.close();
    await pumpEventQueue();

    expect(recorded.length, 2);
    expect(recorded[0].chapterIndex, 0, reason: '离开第一章时应结束第一章会话');
    expect(recorded[1].chapterIndex, 1, reason: '关闭时应结束第二章会话');
    expect(recorded[0].endOffset, 10, reason: '第一章会话结束于离开前的偏移');
    expect(recorded[1].startOffset, 12, reason: '第二章会话从进入时的偏移开始');
  });

  test('persists reading progress to the persistence layer on close', () async {
    final reader = _MockFlureadium();
    final config = _MockReaderConfig();
    final theme = _MockPersistedSignal<ReaderTheme>();
    final fontSize = _MockPersistedSignal<double>();
    final padding = _MockPersistedSignal<double>();
    final fontFamily = _MockPersistedSignal<String>();
    final bgIndex = _MockPersistedSignal<int>();
    final publication = Publication(
      metadata: Metadata(
        localizedTitle: LocalizedString.fromString('Test Book'),
      ),
      readingOrder: [
        const Link(href: 'chapter.xhtml', type: 'application/xhtml+xml'),
      ],
    );

    when(() => config.theme).thenReturn(theme);
    when(() => theme.value).thenReturn(ReaderTheme.light);
    when(() => config.fontSize).thenReturn(fontSize);
    when(() => fontSize.value).thenReturn(100);
    when(() => config.padding).thenReturn(padding);
    when(() => padding.value).thenReturn(20);
    when(() => config.fontFamily).thenReturn(fontFamily);
    when(() => fontFamily.value).thenReturn('System');
    when(() => config.readerBgColorIndex).thenReturn(bgIndex);
    when(() => bgIndex.value).thenReturn(0);
    when(
      () => reader.openPublication(any()),
    ).thenAnswer((_) async => publication);
    when(() => reader.onReaderStatusChanged)
        .thenAnswer((_) => const Stream.empty());
    when(() => reader.onErrorEvent).thenAnswer((_) => const Stream.empty());
    when(() => reader.setEPUBPreferences(any())).thenAnswer((_) async {});
    when(() => reader.setNavigationConfig(any())).thenAnswer((_) async {});
    when(() => reader.closePublication()).thenAnswer((_) async {});

    ReadingProgress? saved;
    final vm = ReadiumViewModel(
      config: config,
      bookId: 'book-progress',
      reader: reader,
      persistProgress: (p) async {
        saved = p;
      },
    );

    await vm.open('book.epub');
    await vm.onViewportReady();
    vm.onLocatorChanged(
      const Locator(
        href: 'chapter.xhtml',
        type: 'application/xhtml+xml',
        locations: Locations(position: 7, totalProgression: 0.5),
      ),
    );
    await vm.close();

    expect(saved, isNotNull, reason: '关闭时应向持久层写入进度');
    expect(saved!.bookId, 'book-progress');
    expect(saved!.chapterIndex, 0);
    expect(saved!.charOffset, 7, reason: '全书字符数未知时退化为页码位置');
    expect(saved!.progress, 0.5);
    expect(saved!.isCompleted, isFalse);
  });

  test('flush ends the session once without closing the publication', () async {
    final reader = _MockFlureadium();
    final config = _MockReaderConfig();
    final theme = _MockPersistedSignal<ReaderTheme>();
    final fontSize = _MockPersistedSignal<double>();
    final padding = _MockPersistedSignal<double>();
    final fontFamily = _MockPersistedSignal<String>();
    final bgIndex = _MockPersistedSignal<int>();
    final publication = Publication(
      metadata: Metadata(
        localizedTitle: LocalizedString.fromString('Test Book'),
      ),
      readingOrder: [
        const Link(href: 'chapter.xhtml', type: 'application/xhtml+xml'),
      ],
    );

    when(() => config.theme).thenReturn(theme);
    when(() => theme.value).thenReturn(ReaderTheme.light);
    when(() => config.fontSize).thenReturn(fontSize);
    when(() => fontSize.value).thenReturn(100);
    when(() => config.padding).thenReturn(padding);
    when(() => padding.value).thenReturn(20);
    when(() => config.fontFamily).thenReturn(fontFamily);
    when(() => fontFamily.value).thenReturn('System');
    when(() => config.readerBgColorIndex).thenReturn(bgIndex);
    when(() => bgIndex.value).thenReturn(0);
    when(
      () => reader.openPublication(any()),
    ).thenAnswer((_) async => publication);
    when(() => reader.onReaderStatusChanged)
        .thenAnswer((_) => const Stream.empty());
    when(() => reader.onErrorEvent).thenAnswer((_) => const Stream.empty());
    when(() => reader.setEPUBPreferences(any())).thenAnswer((_) async {});
    when(() => reader.setNavigationConfig(any())).thenAnswer((_) async {});
    when(() => reader.closePublication()).thenAnswer((_) async {});

    var sessionCount = 0;
    final vm = ReadiumViewModel(
      config: config,
      bookId: 'book-flush',
      reader: reader,
      sessionRecorder: ({
        required bookId,
        required chapterIndex,
        required startCharOffset,
        required endCharOffset,
        required startedAt,
      }) async {
        sessionCount++;
      },
    );

    await vm.open('book.epub');
    await vm.onViewportReady();
    vm.onLocatorChanged(
      const Locator(
        href: 'chapter.xhtml',
        type: 'application/xhtml+xml',
        locations: Locations(position: 3, totalProgression: 0.1),
      ),
    );

    await vm.flush();
    await pumpEventQueue();
    expect(sessionCount, 1, reason: 'flush 应结束当前会话');
    await vm.flush();
    expect(sessionCount, 1, reason: 'flush 幂等：无活跃会话时不重复记录');
    await vm.close();
    expect(sessionCount, 1, reason: 'flush 之后 close 不应再记录会话');
    await vm.close();
    expect(sessionCount, 1, reason: 'flush 之后 close 不应再记录会话');
  });

  test('persists the Locator as an engine position hint on close', () async {
    final reader = _MockFlureadium();
    final config = _MockReaderConfig();
    final theme = _MockPersistedSignal<ReaderTheme>();
    final fontSize = _MockPersistedSignal<double>();
    final padding = _MockPersistedSignal<double>();
    final fontFamily = _MockPersistedSignal<String>();
    final bgIndex = _MockPersistedSignal<int>();
    final publication = Publication(
      metadata: Metadata(
        localizedTitle: LocalizedString.fromString('Test Book'),
        identifier: 'epub-fingerprint-1',
      ),
      readingOrder: [
        const Link(href: 'chapter.xhtml', type: 'application/xhtml+xml'),
      ],
    );

    when(() => config.theme).thenReturn(theme);
    when(() => theme.value).thenReturn(ReaderTheme.light);
    when(() => config.fontSize).thenReturn(fontSize);
    when(() => fontSize.value).thenReturn(100);
    when(() => config.padding).thenReturn(padding);
    when(() => padding.value).thenReturn(20);
    when(() => config.fontFamily).thenReturn(fontFamily);
    when(() => fontFamily.value).thenReturn('System');
    when(() => config.readerBgColorIndex).thenReturn(bgIndex);
    when(() => bgIndex.value).thenReturn(0);
    when(
      () => reader.openPublication(any()),
    ).thenAnswer((_) async => publication);
    when(() => reader.onReaderStatusChanged)
        .thenAnswer((_) => const Stream.empty());
    when(() => reader.onErrorEvent).thenAnswer((_) => const Stream.empty());
    when(() => reader.setEPUBPreferences(any())).thenAnswer((_) async {});
    when(() => reader.setNavigationConfig(any())).thenAnswer((_) async {});
    when(() => reader.closePublication()).thenAnswer((_) async {});

    EnginePositionHint? savedHint;
    final vm = ReadiumViewModel(
      config: config,
      bookId: 'book-locator',
      reader: reader,
      enginePositionSaver: ({required hint}) async {
        savedHint = hint;
      },
    );

    await vm.open('book.epub');
    await vm.onViewportReady();
    vm.onLocatorChanged(
      const Locator(
        href: 'chapter.xhtml',
        type: 'application/xhtml+xml',
        locations: Locations(position: 7, totalProgression: 0.5),
      ),
    );
    await vm.close();

    expect(savedHint, isNotNull, reason: '关闭时应保存引擎位置提示');
    expect(savedHint!.engineKind, 'readium');
    expect(savedHint!.publicationFingerprint, 'epub-fingerprint-1');
    final restored = Locator.fromJson(
      jsonDecode(savedHint!.opaquePosition) as Map<String, dynamic>,
    );
    expect(restored?.href, 'chapter.xhtml');
    expect(restored?.locations?.position, 7);
  });

  test('restores the saved Locator when the fingerprint matches', () async {
    final reader = _MockFlureadium();
    final config = _MockReaderConfig();
    final theme = _MockPersistedSignal<ReaderTheme>();
    final fontSize = _MockPersistedSignal<double>();
    final padding = _MockPersistedSignal<double>();
    final fontFamily = _MockPersistedSignal<String>();
    final bgIndex = _MockPersistedSignal<int>();
    final publication = Publication(
      metadata: Metadata(
        localizedTitle: LocalizedString.fromString('Test Book'),
        identifier: 'epub-fingerprint-1',
      ),
      readingOrder: [
        const Link(href: 'chapter.xhtml', type: 'application/xhtml+xml'),
      ],
    );

    when(() => config.theme).thenReturn(theme);
    when(() => theme.value).thenReturn(ReaderTheme.light);
    when(() => config.fontSize).thenReturn(fontSize);
    when(() => fontSize.value).thenReturn(100);
    when(() => config.padding).thenReturn(padding);
    when(() => padding.value).thenReturn(20);
    when(() => config.fontFamily).thenReturn(fontFamily);
    when(() => fontFamily.value).thenReturn('System');
    when(() => config.readerBgColorIndex).thenReturn(bgIndex);
    when(() => bgIndex.value).thenReturn(0);
    when(
      () => reader.openPublication(any()),
    ).thenAnswer((_) async => publication);
    when(() => reader.onReaderStatusChanged)
        .thenAnswer((_) => const Stream.empty());
    when(() => reader.onErrorEvent).thenAnswer((_) => const Stream.empty());
    when(() => reader.setEPUBPreferences(any())).thenAnswer((_) async {});
    when(() => reader.setNavigationConfig(any())).thenAnswer((_) async {});
    when(() => reader.closePublication()).thenAnswer((_) async {});

    final stored = EnginePositionHint(
      bookId: 'book-locator-restore',
      engineKind: 'readium',
      publicationFingerprint: 'epub-fingerprint-1',
      opaquePosition: jsonEncode(
        const Locator(
          href: 'saved-chapter.xhtml',
          type: 'application/xhtml+xml',
          locations: Locations(position: 42, totalProgression: 0.9),
        ).toJson(),
      ),
      updatedAt: DateTime.now().toUtc(),
    );
    final vm = ReadiumViewModel(
      config: config,
      bookId: 'book-locator-restore',
      reader: reader,
      enginePositionLoader: ({required bookId}) async => stored,
    );

    await vm.open('book.epub');

    expect(vm.initialLocator?.href, 'saved-chapter.xhtml');
    expect(vm.initialLocator?.locations?.position, 42);
  });

  test('discards the saved Locator when the fingerprint does not match', () async {
    final reader = _MockFlureadium();
    final config = _MockReaderConfig();
    final theme = _MockPersistedSignal<ReaderTheme>();
    final fontSize = _MockPersistedSignal<double>();
    final padding = _MockPersistedSignal<double>();
    final fontFamily = _MockPersistedSignal<String>();
    final bgIndex = _MockPersistedSignal<int>();
    final publication = Publication(
      metadata: Metadata(
        localizedTitle: LocalizedString.fromString('Test Book'),
        identifier: 'epub-fingerprint-1',
      ),
      readingOrder: [
        const Link(href: 'chapter.xhtml', type: 'application/xhtml+xml'),
      ],
      tableOfContents: [
        const Link(
          href: 'chapter.xhtml',
          type: 'application/xhtml+xml',
          title: 'Chapter 1',
        ),
      ],
    );

    when(() => config.theme).thenReturn(theme);
    when(() => theme.value).thenReturn(ReaderTheme.light);
    when(() => config.fontSize).thenReturn(fontSize);
    when(() => fontSize.value).thenReturn(100);
    when(() => config.padding).thenReturn(padding);
    when(() => padding.value).thenReturn(20);
    when(() => config.fontFamily).thenReturn(fontFamily);
    when(() => fontFamily.value).thenReturn('System');
    when(() => config.readerBgColorIndex).thenReturn(bgIndex);
    when(() => bgIndex.value).thenReturn(0);
    when(
      () => reader.openPublication(any()),
    ).thenAnswer((_) async => publication);
    when(() => reader.onReaderStatusChanged)
        .thenAnswer((_) => const Stream.empty());
    when(() => reader.onErrorEvent).thenAnswer((_) => const Stream.empty());
    when(() => reader.setEPUBPreferences(any())).thenAnswer((_) async {});
    when(() => reader.setNavigationConfig(any())).thenAnswer((_) async {});
    when(() => reader.closePublication()).thenAnswer((_) async {});

    final stored = EnginePositionHint(
      bookId: 'book-locator-stale',
      engineKind: 'readium',
      publicationFingerprint: 'old-fingerprint',
      opaquePosition: jsonEncode(
        const Locator(
          href: 'stale-chapter.xhtml',
          type: 'application/xhtml+xml',
        ).toJson(),
      ),
      updatedAt: DateTime.now().toUtc(),
    );
    final vm = ReadiumViewModel(
      config: config,
      bookId: 'book-locator-stale',
      reader: reader,
      enginePositionLoader: ({required bookId}) async => stored,
    );

    await vm.open('book.epub');

    expect(
      vm.initialLocator?.href,
      'chapter.xhtml',
      reason: '指纹不匹配时丢弃旧 Locator，退回目录首章',
    );
  });
}
