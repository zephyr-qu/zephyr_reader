import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zephyr_reader/core/reader_engine/layout/layout_spec.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/packed_page.dart'
    show ReaderIrBlockLayout;
import 'package:zephyr_reader/core/reader_engine/pagination/page_plan.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/block_page_content.dart';
import 'package:zephyr_reader/core/reader_engine/shared/ir_types.dart';
import 'package:zephyr_reader/src/rust/pipeline/types.dart';

Widget _wrap(Widget w) => MaterialApp(home: Scaffold(body: w));

void main() {
  group('buildPagePlanContent', () {
    testWidgets('renders text fragment without errors', (tester) async {
      final page = const PagePlan(
        pageIndex: 0,
        startUtf16: 0,
        endUtf16: 4,
        fragments: [
          PageFragment.text(
            blockIndex: 0,
            startUtf16: 0,
            endUtf16: 4,
            isBlockStart: true,
            isBlockEnd: true,
            text: 'Test',
            spans: [],
            style: BlockStyle(isHeading: false, headingLevel: 0),
          ),
        ],
        isLastPage: true,
      );
      final spec = const LayoutSpec(
        viewportWidth: 400,
        viewportHeight: 600,
        contentPadding: 20,
        fontFamily: 'sans-serif',
        fontSize: 16,
        lineHeight: 1.5,
        paragraphSpacing: 8,
      );

      await tester.pumpWidget(_wrap(
        buildPagePlanContent(
          context: tester.element(find.byType(MaterialApp)),
          page: page,
          spec: spec,
          highlights: const [],
          epubFilePath: '',
          onHighlightTap: null,
          onSelectionChanged: null,
          onSelectionGlobalPosition: null,
          maxContentWidth: 360,
        ),
      ));

      // Renders without crash → the SelectableText.rich created text
      expect(find.text('Test'), findsOneWidget);
    });

    testWidgets('renders image fragment as placeholder', (tester) async {
      final page = PagePlan(
        pageIndex: 0,
        startUtf16: 0,
        endUtf16: 1,
        fragments: [
          PageFragment.image(
            blockIndex: 0,
            startUtf16: 0,
            endUtf16: 1,
            assetId: 'test.png',
            imageLayout: ReaderIrBlockLayout.inlineContain,
            imageAlt: 'Test image',
            intrinsicWidth: 100,
            intrinsicHeight: 100,
          ),
        ],
        isLastPage: true,
      );
      final spec = const LayoutSpec(
        viewportWidth: 400,
        viewportHeight: 600,
        contentPadding: 20,
        fontFamily: 'sans-serif',
        fontSize: 16,
        lineHeight: 1.5,
        paragraphSpacing: 8,
      );

      await tester.pumpWidget(_wrap(
        buildPagePlanContent(
          context: tester.element(find.byType(MaterialApp)),
          page: page,
          spec: spec,
          highlights: const [],
          epubFilePath: 'test.epub',
          onHighlightTap: null,
          onSelectionChanged: null,
          onSelectionGlobalPosition: null,
          maxContentWidth: 360,
        ),
      ));

      // Renders without crash; placeholder icon visible.
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });
  });
}
