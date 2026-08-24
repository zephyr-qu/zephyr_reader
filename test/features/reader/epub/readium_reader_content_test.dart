import 'dart:async';

// Readium test fixtures require non-const localized metadata constructors.
// ignore_for_file: prefer_const_literals_to_create_immutables

import 'package:flutter_readium/flutter_readium.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/reading/config/reader_config.dart';
import 'package:zephyr_reader/features/reader/epub/readium_reader_content.dart';
import 'package:zephyr_reader/features/reader/epub/readium_view_model.dart';

class _MockReadiumViewModel extends Mock implements ReadiumViewModel {}

Publication _publication({
  ReadingProgression progression = ReadingProgression.ltr,
}) => Publication(
  metadata: Metadata(
    localizedTitle: LocalizedString.fromString('Test Book'),
    identifier: 'test-book',
    readingProgression: progression,
  ),
  readingOrder: [
    const Link(href: 'chapter.xhtml', type: 'application/xhtml+xml'),
  ],
);

void main() {
  setUpAll(() {
    registerFallbackValue(
      const Locator(href: 'fallback.xhtml', type: 'application/xhtml+xml'),
    );
  });

  testWidgets('retry replaces the failed open future', (tester) async {
    final vm = _MockReadiumViewModel();
    final retryCompleter = Completer<Publication>();
    var attempts = 0;

    when(() => vm.error).thenReturn(signal<String?>(null));
    when(
      () => vm.readingMode,
    ).thenReturn(signal<ReadingMode>(ReadingMode.pagination));
    when(() => vm.onViewportReady()).thenAnswer((_) async {});
    when(() => vm.open(any())).thenAnswer((_) {
      attempts += 1;
      if (attempts == 1) {
        return Future<Publication>.error(StateError('open failed'));
      }
      return retryCompleter.future;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReadiumReaderContent(vm: vm, filePath: 'broken.epub'),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('open failed'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pump();

    expect(attempts, 2);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('open failed'), findsNothing);

    retryCompleter.complete(_publication());
    await tester.pump();
    await tester.pump();
    expect(find.byType(ReadiumReaderWidget), findsOneWidget);
  });

  testWidgets('successful open wires the native viewport callbacks', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final vm = _MockReadiumViewModel();
    final publication = _publication();
    const initialLocator = Locator(
      href: 'chapter.xhtml',
      type: 'application/xhtml+xml',
    );
    when(() => vm.open(any())).thenAnswer((_) async => publication);
    when(
      () => vm.readingMode,
    ).thenReturn(signal<ReadingMode>(ReadingMode.pagination));
    when(() => vm.initialLocator).thenReturn(initialLocator);
    when(() => vm.onViewportReady()).thenAnswer((_) async {
      return;
    });
    when(() => vm.onLocatorChanged(any())).thenReturn(null);
    when(() => vm.goLeft()).thenAnswer((_) async {
      return;
    });
    when(() => vm.goRight()).thenAnswer((_) async {
      return;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReadiumReaderContent(vm: vm, filePath: 'book.epub'),
        ),
      ),
    );
    await tester.pump();

    final viewport = tester.widget<ReadiumReaderWidget>(
      find.byType(ReadiumReaderWidget),
    );
    expect(viewport.publication, same(publication));
    expect(viewport.initialLocator, same(initialLocator));
    expect(
      tester.getSize(find.byType(ReadiumReaderWidget)),
      tester.getSize(find.byType(ReadiumReaderContent)),
    );
    expect(
      tester.getSize(find.byType(ReadiumReaderWidget)),
      const Size(400, 800),
    );
    verify(() => vm.onViewportReady()).called(1);
  });

  testWidgets('pagination turns pages after a horizontal fling', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final vm = _MockReadiumViewModel();
    final publication = _publication();

    when(() => vm.open(any())).thenAnswer((_) async => publication);
    when(
      () => vm.readingMode,
    ).thenReturn(signal<ReadingMode>(ReadingMode.pagination));
    when(() => vm.initialLocator).thenReturn(null);
    when(() => vm.onViewportReady()).thenAnswer((_) async {});
    when(() => vm.onLocatorChanged(any())).thenReturn(null);
    when(() => vm.goLeft()).thenAnswer((_) async {});
    when(() => vm.goRight()).thenAnswer((_) async {});

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReadiumReaderContent(vm: vm, filePath: 'book.epub'),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.ancestor(
        of: find.byType(ReadiumReaderWidget),
        matching: find.byType(GestureDetector),
      ),
      findsOneWidget,
      reason: 'pagination needs one Flutter threshold for responsive swipes',
    );

    await tester.fling(
      find.byType(ReadiumReaderWidget),
      const Offset(-180, 0),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    verify(() => vm.goRight()).called(1);
  });

  testWidgets('pagination reverses horizontal fling direction for RTL books', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final vm = _MockReadiumViewModel();
    final publication = _publication(progression: ReadingProgression.rtl);

    when(() => vm.open(any())).thenAnswer((_) async => publication);
    when(
      () => vm.readingMode,
    ).thenReturn(signal<ReadingMode>(ReadingMode.pagination));
    when(() => vm.initialLocator).thenReturn(null);
    when(() => vm.onViewportReady()).thenAnswer((_) async {});
    when(() => vm.onLocatorChanged(any())).thenReturn(null);
    when(() => vm.goLeft()).thenAnswer((_) async {});
    when(() => vm.goRight()).thenAnswer((_) async {});

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReadiumReaderContent(vm: vm, filePath: 'rtl-book.epub'),
        ),
      ),
    );
    await tester.pump();

    await tester.fling(
      find.byType(ReadiumReaderWidget),
      const Offset(-180, 0),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    verify(() => vm.goLeft()).called(1);
    verifyNever(() => vm.goRight());
  });

  testWidgets('reading mode changes recreate the native viewport in place', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final vm = _MockReadiumViewModel();
    final publication = _publication();
    final mode = signal<ReadingMode>(ReadingMode.pagination);
    const locator = Locator(
      href: 'chapter.xhtml',
      type: 'application/xhtml+xml',
      locations: Locations(totalProgression: 0.42),
    );

    when(() => vm.open(any())).thenAnswer((_) async => publication);
    when(() => vm.readingMode).thenReturn(mode);
    when(() => vm.initialLocator).thenReturn(null);
    when(() => vm.currentLocator).thenReturn(locator);
    when(() => vm.onViewportReady()).thenAnswer((_) async {});
    when(() => vm.onLocatorChanged(any())).thenReturn(null);

    Widget buildReader() => MaterialApp(
      home: Scaffold(
        body: ReadiumReaderContent(vm: vm, filePath: 'book.epub'),
      ),
    );

    await tester.pumpWidget(buildReader());
    await tester.pump();
    final before = tester.state<State>(find.byType(ReadiumReaderWidget));

    mode.value = ReadingMode.scroll;
    await tester.pumpWidget(buildReader());
    await tester.pump();

    final after = tester.state<State>(find.byType(ReadiumReaderWidget));
    expect(identical(before, after), isFalse);
    expect(
      tester
          .widget<ReadiumReaderWidget>(find.byType(ReadiumReaderWidget))
          .initialLocator,
      locator,
    );
    expect(
      find.ancestor(
        of: find.byType(ReadiumReaderWidget),
        matching: find.byType(GestureDetector),
      ),
      findsOneWidget,
      reason: 'mode changes must not reparent the native Platform View',
    );
  });

  testWidgets('text alignment changes keep the native viewport in place', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final vm = _MockReadiumViewModel();
    final publication = _publication();
    const locator = Locator(
      href: 'chapter.xhtml',
      type: 'application/xhtml+xml',
      locations: Locations(totalProgression: 0.42),
    );

    when(() => vm.open(any())).thenAnswer((_) async => publication);
    when(
      () => vm.readingMode,
    ).thenReturn(signal<ReadingMode>(ReadingMode.pagination));
    when(() => vm.initialLocator).thenReturn(locator);
    when(() => vm.currentLocator).thenReturn(locator);
    when(() => vm.onViewportReady()).thenAnswer((_) async {});
    when(() => vm.onLocatorChanged(any())).thenReturn(null);

    Widget buildReader() => MaterialApp(
      home: Scaffold(
        body: ReadiumReaderContent(vm: vm, filePath: 'book.epub'),
      ),
    );

    await tester.pumpWidget(buildReader());
    await tester.pump();
    final before = tester.state<State>(find.byType(ReadiumReaderWidget));

    await tester.pumpWidget(buildReader());
    await tester.pump();

    final after = tester.state<State>(find.byType(ReadiumReaderWidget));
    expect(identical(before, after), isTrue);
    expect(
      tester
          .widget<ReadiumReaderWidget>(find.byType(ReadiumReaderWidget))
          .initialLocator,
      locator,
    );
  });

  testWidgets('scroll mode does not force horizontal page navigation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final vm = _MockReadiumViewModel();
    final publication = _publication();

    when(() => vm.open(any())).thenAnswer((_) async => publication);
    when(
      () => vm.readingMode,
    ).thenReturn(signal<ReadingMode>(ReadingMode.scroll));
    when(() => vm.initialLocator).thenReturn(null);
    when(() => vm.onViewportReady()).thenAnswer((_) async {
      return;
    });
    when(() => vm.onLocatorChanged(any())).thenReturn(null);
    when(() => vm.goLeft()).thenAnswer((_) async {
      return;
    });
    when(() => vm.goRight()).thenAnswer((_) async {
      return;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReadiumReaderContent(vm: vm, filePath: 'book.epub'),
        ),
      ),
    );
    await tester.pump();

    final gestureDetector = find.ancestor(
      of: find.byType(ReadiumReaderWidget),
      matching: find.byType(GestureDetector),
    );
    expect(gestureDetector, findsOneWidget);
    final gesture = tester.widget<GestureDetector>(gestureDetector);
    expect(gesture.onHorizontalDragStart, isNull);
    expect(gesture.onHorizontalDragUpdate, isNull);
    expect(gesture.onHorizontalDragEnd, isNull);

    await tester.fling(
      find.byType(ReadiumReaderWidget),
      const Offset(-180, 0),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    verifyNever(() => vm.goRight());
    verifyNever(() => vm.goLeft());
  });

  testWidgets('scroll mode fling does not trigger chapter navigation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final vm = _MockReadiumViewModel();
    final publication = _publication();

    when(() => vm.open(any())).thenAnswer((_) async => publication);
    when(
      () => vm.readingMode,
    ).thenReturn(signal<ReadingMode>(ReadingMode.scroll));
    when(() => vm.initialLocator).thenReturn(null);
    when(() => vm.onViewportReady()).thenAnswer((_) async {
      return;
    });
    when(() => vm.onLocatorChanged(any())).thenReturn(null);
    when(() => vm.goLeft()).thenAnswer((_) async {
      return;
    });
    when(() => vm.goRight()).thenAnswer((_) async {
      return;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReadiumReaderContent(vm: vm, filePath: 'book.epub'),
        ),
      ),
    );
    await tester.pump();

    // 章节内滚动交由原生 WebView；Flutter 层垂直滑动不得拦截成跳章。
    await tester.fling(
      find.byType(ReadiumReaderWidget),
      const Offset(0, -180),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    verifyNever(() => vm.goLeft());
    verifyNever(() => vm.goRight());
  });
}
