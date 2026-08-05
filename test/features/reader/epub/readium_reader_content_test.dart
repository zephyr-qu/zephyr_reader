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

Publication _publication() => Publication(
  metadata: Metadata(
    localizedTitle: LocalizedString.fromString('Test Book'),
    identifier: 'test-book',
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
    var viewportTapCount = 0;

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
          body: ReadiumReaderContent(
            vm: vm,
            filePath: 'book.epub',
            onViewportTap: () => viewportTapCount += 1,
          ),
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

    final outerGesture = tester.widget<GestureDetector>(
      find
          .ancestor(
            of: find.byType(ReadiumReaderWidget),
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    expect(outerGesture.onTap, isNotNull);
    outerGesture.onTap!();
    await tester.pump();

    verify(() => vm.onViewportReady()).called(1);
    expect(viewportTapCount, 1);

    await tester.fling(
      find.byType(ReadiumReaderWidget),
      const Offset(-180, 0),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    verify(() => vm.goRight()).called(1);
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

    final horizontalGesture = tester.widget<GestureDetector>(
      find
          .ancestor(
            of: find.byType(ReadiumReaderWidget),
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    expect(
      horizontalGesture.onHorizontalDragStart,
      isNotNull,
      reason: '滚动模式应拦截横划，避免原生视口用横划切章',
    );

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
