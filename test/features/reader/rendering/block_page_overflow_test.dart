import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/rendering/paginated_page_viewport.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PaginatedPageViewport overflow', () {
    testWidgets('D1 content within viewport', (tester) async {
      const maxH = 400.0;
      const maxW = 328.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaginatedPageViewport(
              maxHeight: maxH,
              maxWidth: maxW,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  3,
                  (i) => Text(
                    'Block $i: 这是一段测试文本用于验证视口不溢出。',
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final box =
          tester.renderObject(find.byType(PaginatedPageViewport)) as RenderBox;
      final size = box.size;
      expect(
        size.height,
        lessThanOrEqualTo(maxH + 0.5),
        reason:
            'PaginatedPageViewport height ${size.height} '
            'should not exceed $maxH',
      );
      expect(size.width, lessThanOrEqualTo(maxW + 0.5));
    });

    testWidgets('D2 long content constrained', (tester) async {
      const maxH = 300.0;
      const maxW = 328.0;
      final longText = '中' * 500;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaginatedPageViewport(
              maxHeight: maxH,
              maxWidth: maxW,
              child: SelectableText(
                longText,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),
          ),
        ),
      );

      final box =
          tester.renderObject(find.byType(PaginatedPageViewport)) as RenderBox;
      final size = box.size;
      expect(
        size.height,
        lessThanOrEqualTo(maxH + 0.5),
        reason:
            'PaginatedPageViewport height ${size.height} '
            'should not exceed $maxH with long CJK text',
      );
    });
  });
}
