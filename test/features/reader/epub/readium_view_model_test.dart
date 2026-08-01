import 'dart:async';

import 'package:flureadium/flureadium.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr_reader/core/reading/config/reader_config.dart';
import 'package:zephyr_reader/core/settings/persisted_signal.dart';
import 'package:zephyr_reader/features/reader/epub/readium_view_model.dart';

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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
}
