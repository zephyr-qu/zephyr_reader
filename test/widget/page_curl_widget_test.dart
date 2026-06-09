// test/widget/page_curl_widget_test.dart
//
// PageCurlWidget 仿真翻页测试 — 覆盖手势交互、边界守卫、翻页回调

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zephyr_reader/features/reader/page/widgets/page_curl_widget.dart';

/// 构建测试用 PageCurlWidget 包装
Widget _buildCurlApp({
  int pageIndex = 0,
  int totalPages = 5,
  void Function(int)? onPageChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 300,
          height: 400,
          child: PageCurlWidget(
            pageIndex: pageIndex,
            totalPages: totalPages,
            pageBuilder: (i) => Container(
              color: Colors.white,
              child: Center(
                child: Text('Page $i', textDirection: TextDirection.ltr),
              ),
            ),
            onPageChanged: onPageChanged ?? (_) {},
          ),
        ),
      ),
    ),
  );
}

/// 获取 PageCurlWidget 的全局位置和尺寸
(Offset offset, Size size) _getWidgetGeometry(WidgetTester tester) {
  final finder = find.byType(PageCurlWidget);
  return (tester.getTopLeft(finder), tester.getSize(finder));
}

void main() {
  group('PageCurlWidget', () {
    // ── 闲时状态 ──
    testWidgets('idle state shows current page only', (tester) async {
      await tester.pumpWidget(_buildCurlApp(pageIndex: 2, totalPages: 5));

      expect(find.text('Page 2'), findsOneWidget);
      // Next/prev pages should not appear
      expect(find.text('Page 3'), findsNothing);
      expect(find.text('Page 1'), findsNothing);
      // No clip path in idle state
      expect(find.byType(ClipPath), findsNothing);
    });

    // ── 点击翻页 ──
    testWidgets('tap right third calls onPageChanged forward', (tester) async {
      int? changedTo;
      await tester.pumpWidget(
        _buildCurlApp(
          pageIndex: 0,
          totalPages: 5,
          onPageChanged: (p) => changedTo = p,
        ),
      );

      final (topLeft, size) = _getWidgetGeometry(tester);
      // Tap right third (forward)
      await tester.tapAt(topLeft + Offset(size.width * 0.9, size.height / 2));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(changedTo, equals(1));
    });

    testWidgets('tap left third calls onPageChanged backward', (tester) async {
      int? changedTo;
      await tester.pumpWidget(
        _buildCurlApp(
          pageIndex: 3,
          totalPages: 5,
          onPageChanged: (p) => changedTo = p,
        ),
      );

      final (topLeft, size) = _getWidgetGeometry(tester);
      // Tap left third (backward)
      await tester.tapAt(topLeft + Offset(size.width * 0.1, size.height / 2));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(changedTo, equals(2));
    });

    testWidgets('tap center third does not change page', (tester) async {
      int? changedTo;
      await tester.pumpWidget(
        _buildCurlApp(
          pageIndex: 2,
          totalPages: 5,
          onPageChanged: (p) => changedTo = p,
        ),
      );

      final (topLeft, size) = _getWidgetGeometry(tester);
      // Tap center third
      await tester.tapAt(topLeft + Offset(size.width * 0.5, size.height / 2));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(changedTo, isNull);
    });

    // ── 边界守卫 ──
    testWidgets('first page: tap left does nothing', (tester) async {
      int? changedTo;
      await tester.pumpWidget(
        _buildCurlApp(
          pageIndex: 0,
          totalPages: 5,
          onPageChanged: (p) => changedTo = p,
        ),
      );

      final (topLeft, size) = _getWidgetGeometry(tester);
      await tester.tapAt(topLeft + Offset(size.width * 0.1, size.height / 2));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(changedTo, isNull);
    });

    testWidgets('last page: tap right does nothing', (tester) async {
      int? changedTo;
      await tester.pumpWidget(
        _buildCurlApp(
          pageIndex: 4,
          totalPages: 5,
          onPageChanged: (p) => changedTo = p,
        ),
      );

      final (topLeft, size) = _getWidgetGeometry(tester);
      await tester.tapAt(topLeft + Offset(size.width * 0.9, size.height / 2));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(changedTo, isNull);
    });

    // ── 拖拽翻页（> 30%） ──
    testWidgets('drag right→left >30% turns forward', (tester) async {
      int? changedTo;
      await tester.pumpWidget(
        _buildCurlApp(
          pageIndex: 0,
          totalPages: 5,
          onPageChanged: (p) => changedTo = p,
        ),
      );

      final (topLeft, size) = _getWidgetGeometry(tester);
      // Drag from right side to left, covering 60% of width
      final start = topLeft + Offset(size.width * 0.9, size.height / 2);
      final offset = Offset(-size.width * 0.6, 0);
      await tester.timedDragFrom(
        start,
        offset,
        const Duration(milliseconds: 200),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(changedTo, equals(1));
    });

    testWidgets('drag left→right >30% turns backward', (tester) async {
      int? changedTo;
      await tester.pumpWidget(
        _buildCurlApp(
          pageIndex: 3,
          totalPages: 5,
          onPageChanged: (p) => changedTo = p,
        ),
      );

      final (topLeft, size) = _getWidgetGeometry(tester);
      // Drag from left side to right, covering 60% of width
      final start = topLeft + Offset(size.width * 0.1, size.height / 2);
      final offset = Offset(size.width * 0.6, 0);
      await tester.timedDragFrom(
        start,
        offset,
        const Duration(milliseconds: 200),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(changedTo, equals(2));
    });

    // ── 拖拽回弹（< 30%） ──
    testWidgets('drag <30% snaps back, no page change', (tester) async {
      int? changedTo;
      await tester.pumpWidget(
        _buildCurlApp(
          pageIndex: 2,
          totalPages: 5,
          onPageChanged: (p) => changedTo = p,
        ),
      );

      final (topLeft, size) = _getWidgetGeometry(tester);
      // Drag right → left covering only 20% of width
      final start = topLeft + Offset(size.width * 0.5, size.height / 2);
      final offset = Offset(-size.width * 0.2, 0);
      await tester.timedDragFrom(
        start,
        offset,
        const Duration(milliseconds: 200),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(changedTo, isNull);
    });

    // ── 边界拖拽 ──
    testWidgets('last page: drag forward snaps back', (tester) async {
      int? changedTo;
      await tester.pumpWidget(
        _buildCurlApp(
          pageIndex: 4,
          totalPages: 5,
          onPageChanged: (p) => changedTo = p,
        ),
      );

      final (topLeft, size) = _getWidgetGeometry(tester);
      final start = topLeft + Offset(size.width * 0.9, size.height / 2);
      final offset = Offset(-size.width * 0.6, 0);
      await tester.timedDragFrom(
        start,
        offset,
        const Duration(milliseconds: 200),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(changedTo, isNull);
    });

    testWidgets('first page: drag backward snaps back', (tester) async {
      int? changedTo;
      await tester.pumpWidget(
        _buildCurlApp(
          pageIndex: 0,
          totalPages: 5,
          onPageChanged: (p) => changedTo = p,
        ),
      );

      final (topLeft, size) = _getWidgetGeometry(tester);
      final start = topLeft + Offset(size.width * 0.1, size.height / 2);
      final offset = Offset(size.width * 0.6, 0);
      await tester.timedDragFrom(
        start,
        offset,
        const Duration(milliseconds: 200),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(changedTo, isNull);
    });

    // ── 外部 pageIndex 变化重置状态 ──
    testWidgets('external pageIndex change shows new page', (tester) async {
      int pageIndex = 0;
      await tester.pumpWidget(
        _buildCurlApp(pageIndex: pageIndex, totalPages: 5),
      );

      expect(find.text('Page 0'), findsOneWidget);

      // Simulate external page change (VM signal update)
      pageIndex = 2;
      await tester.pumpWidget(
        _buildCurlApp(pageIndex: pageIndex, totalPages: 5),
      );
      await tester.pump();

      expect(find.text('Page 2'), findsOneWidget);
      expect(find.text('Page 0'), findsNothing);
    });

    // ── 下一页在卷曲时渲染 ──
    testWidgets('next page appears beneath during curl', (tester) async {
      await tester.pumpWidget(_buildCurlApp(pageIndex: 0, totalPages: 5));

      // Initially only current page is visible
      expect(find.text('Page 0'), findsOneWidget);
      expect(find.text('Page 1'), findsNothing);

      final (topLeft, size) = _getWidgetGeometry(tester);
      // Drag just enough to see next page peek through
      final start = topLeft + Offset(size.width * 0.9, size.height / 2);
      final offset = Offset(-size.width * 0.3, 0);
      await tester.timedDragFrom(
        start,
        offset,
        const Duration(milliseconds: 150),
      );
      await tester.pump();

      // During drag, page 1 should appear in the Stack
      expect(find.text('Page 0'), findsOneWidget);
      expect(find.text('Page 1'), findsOneWidget);
    });
  });
}
