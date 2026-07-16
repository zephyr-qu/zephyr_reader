import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/page_curl_widget.dart';

void main() {
  testWidgets('tap on right third turns to the next page', (tester) async {
    int? changedPage;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.expand(
          child: PageCurlWidget(
            pageIndex: 0,
            totalPages: 3,
            pageBuilder: (index) => SizedBox.expand(
              child: ColoredBox(
                color: Colors.white,
                child: Text('page-$index'),
              ),
            ),
            onPageChanged: (index) => changedPage = index,
          ),
        ),
      ),
    );

    final gesture = find.descendant(
      of: find.byType(PageCurlWidget),
      matching: find.byType(GestureDetector),
    );
    final rect = tester.getRect(gesture);
    await tester.tapAt(Offset(rect.right - 1, rect.center.dy));
    await tester.pumpAndSettle();

    expect(changedPage, 1);
  });

  testWidgets('controller animation does not rebuild page contents', (
    tester,
  ) async {
    var pageBuildCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.expand(
          child: PageCurlWidget(
            pageIndex: 0,
            totalPages: 3,
            pageBuilder: (index) {
              pageBuildCount++;
              return SizedBox.expand(
                child: ColoredBox(
                  color: Colors.white,
                  child: Text('page-$index'),
                ),
              );
            },
            onPageChanged: (_) {},
          ),
        ),
      ),
    );
    final initialBuildCount = pageBuildCount;

    final gesture = find.descendant(
      of: find.byType(PageCurlWidget),
      matching: find.byType(GestureDetector),
    );
    final rect = tester.getRect(gesture);
    await tester.tapAt(Offset(rect.right - 1, rect.center.dy));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(pageBuildCount, initialBuildCount);
    await tester.pumpAndSettle();
  });
}
