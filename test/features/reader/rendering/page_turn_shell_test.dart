import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/rendering/page_curl_widget.dart';
import 'package:zephyr_reader/features/reader/rendering/page_turn_shell.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';

void main() {
  testWidgets('maps logical pageIndex to physical index with virtual prev', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PageTurnShell(
          logicalPageIndex: 1,
          logicalPageCount: 3,
          hasPreviousChapter: true,
          hasNextStagingPage: false,
          descriptors: const [
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
              endOffset: 299,
              isLastPage: true,
              firstParagraphIndex: 2,
              lastParagraphIndex: 2,
            ),
          ],
          onLogicalPageChanged: (_) {},
          pageBuilder: (physicalIdx) => Text('page-$physicalIdx'),
        ),
      ),
    );

    final curl = tester.widget<PageCurlWidget>(find.byType(PageCurlWidget));
    expect(curl.pageIndex, 2);
    expect(curl.totalPages, 4);
    expect(find.text('page-2'), findsOneWidget);
  });

  testWidgets('onReachStart fires for virtual previous chapter page', (
    tester,
  ) async {
    var reachStart = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PageTurnShell(
          logicalPageIndex: 0,
          logicalPageCount: 1,
          hasPreviousChapter: true,
          hasNextStagingPage: false,
          onLogicalPageChanged: (_) {},
          onReachStart: () => reachStart++,
          pageBuilder: (_) => const SizedBox(),
        ),
      ),
    );

    final curl = tester.widget<PageCurlWidget>(find.byType(PageCurlWidget));
    curl.onPageChanged(0);
    expect(reachStart, 1);
  });
}
