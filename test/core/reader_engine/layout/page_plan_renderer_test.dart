import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zephyr_reader/core/reader_engine/layout/layout_spec.dart';
import 'package:zephyr_reader/core/reader_engine/layout/paragraph_layouter.dart';
import 'package:zephyr_reader/core/reader_engine/layout/span_factory.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/page_plan.dart'
    show PageFragment, PagePlan, ReaderIrBlockLayout;
import 'package:zephyr_reader/core/reader_engine/pagination/page_packer.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/pagination_viewport_metrics.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/block_page_content.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/reader_render_config.dart';
import 'package:zephyr_reader/src/rust/pipeline/types.dart';

Widget _wrap(Widget w) => MaterialApp(home: Scaffold(body: w));

const _config = ReaderRenderConfig(
  textColor: Colors.green,
  backgroundColor: Colors.white,
  fontSize: 16,
  lineHeight: 1.5,
  fontFamily: 'sans-serif',
  letterSpacing: 0,
  paragraphSpacing: 8,
  pageMargin: 20,
  showVocabularyMark: false,
  vocabularyWords: {},
);

void main() {
  group('buildPagePlanContent', () {
    testWidgets('packed multi-paragraph pages do not overflow when rendered', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const renderConfig = ReaderRenderConfig(
        textColor: Colors.green,
        backgroundColor: Colors.white,
        fontSize: 16,
        lineHeight: 1.8,
        fontFamily: '',
        letterSpacing: 0,
        paragraphSpacing: 8,
        pageMargin: 20,
        showVocabularyMark: false,
        vocabularyWords: {},
        firstLineIndent: true,
      );
      final spec = LayoutSpec.fromRenderConfig(
        renderConfig,
        viewportWidth: 400,
        viewportHeight: 600,
      );
      expect(spec.fontFamily, ReaderRenderConfig.chineseFont);
      const style = BlockStyle(isHeading: false, headingLevel: 0);
      const paragraph =
          '这是用于验证分页测量与实际渲染高度完全一致的正文内容。'
          '同一段文字会覆盖多行，并在页面边界附近触发换页。';
      final layouter = ParagraphLayouter(SpanFactory(spec), spec);
      final packer = PagePacker(spec: spec, maxHeight: 560);
      var plainStart = 0;
      for (var i = 0; i < 30; i++) {
        final text = '$paragraph${i.isEven ? paragraph : ''}';
        final layout = layouter.layoutTextBlock(
          blockIndex: i,
          text: text,
          spans: const [],
          style: style,
          maxWidth: 360,
          firstLineIndentPx: 32,
        );
        packer.appendTextBlock(
          block: layout,
          blockText: text,
          blockRuns: const [],
          blockPlainStart: plainStart,
          blockStyle: style,
        );
        plainStart += text.length;
      }

      final pages = packer.finish();
      for (final page in pages) {
        await tester.pumpWidget(
          _wrap(
            Builder(
              builder: (context) => buildPagePlanContent(
                context: context,
                page: page,
                spec: spec,
                config: renderConfig,
                highlights: const [],
                epubFilePath: '',
                onHighlightTap: null,
                onSelectionChanged: null,
                onSelectionGlobalPosition: null,
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: 'page ${page.pageIndex}');
      }
    });

    testWidgets('reports the real padded content viewport', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 600));
      addTearDown(() {
        PaginationViewportMetrics.clear();
        return tester.binding.setSurfaceSize(null);
      });
      PaginationViewportMetrics.clear();

      const page = PagePlan(
        pageIndex: 0,
        startUtf16: 0,
        endUtf16: 1,
        fragments: [
          PageFragment.text(
            blockIndex: 0,
            startUtf16: 0,
            endUtf16: 1,
            isBlockStart: true,
            isBlockEnd: true,
            text: 'A',
            spans: [],
            style: BlockStyle(isHeading: false, headingLevel: 0),
          ),
        ],
      );
      const spec = LayoutSpec(
        viewportWidth: 400,
        viewportHeight: 600,
        contentPadding: 20,
        fontFamily: 'sans-serif',
        fontSize: 16,
        lineHeight: 1.5,
        paragraphSpacing: 8,
      );

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => buildPagePlanContent(
              context: context,
              page: page,
              spec: spec,
              config: _config,
              highlights: const [],
              epubFilePath: '',
              onHighlightTap: null,
              onSelectionChanged: null,
              onSelectionGlobalPosition: null,
            ),
          ),
        ),
      );

      final actualViewport = tester.getSize(
        find.byType(PaginatedPageViewport),
      );
      expect(PaginationViewportMetrics.contentWidthDp, actualViewport.width);
      expect(PaginationViewportMetrics.contentHeightDp, actualViewport.height);
      expect(actualViewport, const Size(360, 560));
    });

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

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => buildPagePlanContent(
              context: context,
              page: page,
              spec: spec,
              config: _config,
              highlights: const [],
              epubFilePath: '',
              onHighlightTap: null,
              onSelectionChanged: null,
              onSelectionGlobalPosition: null,
            ),
          ),
        ),
      );

      expect(find.byType(SelectableText), findsOneWidget);
      final selectable = tester.widget<SelectableText>(
        find.byType(SelectableText),
      );
      expect(selectable.textSpan?.style?.color, Colors.green);
    });

    testWidgets('renders image fragment as placeholder', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const page = PagePlan(
        pageIndex: 0,
        startUtf16: 0,
        endUtf16: 1,
        fragments: <PageFragment>[
          PageFragment.image(
            blockIndex: 0,
            startUtf16: 0,
            endUtf16: 1,
            assetId: 'test.png',
            imageLayout: ReaderIrBlockLayout.inlineContain,
            imageAlt: 'Test image',
            intrinsicWidth: 100,
            intrinsicHeight: 100,
            imageDisplayWidth: 100,
            imageDisplayHeight: 100,
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

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => buildPagePlanContent(
              context: context,
              page: page,
              spec: spec,
              config: _config,
              highlights: const [],
              epubFilePath: 'test.epub',
              onHighlightTap: null,
              onSelectionChanged: null,
              onSelectionGlobalPosition: null,
            ),
          ),
        ),
      );

      // Renders without crash; placeholder icon visible.
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      final image = tester.widget<EpubBlockImage>(find.byType(EpubBlockImage));
      expect(image.maxWidthPx, 100);
      expect(image.maxHeightPx, 100);
    });
  });
}
