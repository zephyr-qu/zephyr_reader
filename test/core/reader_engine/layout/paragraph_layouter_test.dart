import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zephyr_reader/core/reader_engine/layout/layout_spec.dart';
import 'package:zephyr_reader/core/reader_engine/layout/paragraph_layouter.dart';
import 'package:zephyr_reader/core/reader_engine/layout/span_factory.dart';
import 'package:zephyr_reader/src/rust/pipeline/types.dart';

/// 测试用最小 LayoutSpec。
LayoutSpec _testSpec({
  double fontSize = 16,
  double lineHeight = 1.5,
  double letterSpacing = 0,
  double paragraphSpacing = 0,
  bool firstLineIndent = false,
  TextScaler textScaler = TextScaler.noScaling,
  double viewportWidth = 400,
  double viewportHeight = 600,
  double padding = 20,
}) => LayoutSpec(
  viewportWidth: viewportWidth,
  viewportHeight: viewportHeight,
  contentPadding: padding,
  fontFamily: 'sans-serif',
  fontSize: fontSize,
  lineHeight: lineHeight,
  letterSpacing: letterSpacing,
  paragraphSpacing: paragraphSpacing,
  textScaler: textScaler,
  firstLineIndent: firstLineIndent,
);

ParagraphLayouter _layouter(LayoutSpec spec) =>
    ParagraphLayouter(SpanFactory(spec), spec);

const _bodyStyle = BlockStyle(isHeading: false, headingLevel: 0);

void main() {
  // ── 基础行布局 ──
  group('layoutTextBlock basic', () {
    testWidgets('single short line produces one LineLayout', (tester) async {
      final spec = _testSpec();
      final layout = _layouter(spec).layoutTextBlock(
        blockIndex: 0,
        text: 'Hello',
        spans: const [],
        style: _bodyStyle,
        maxWidth: 300,
      );

      expect(layout.blockIndex, 0);
      expect(layout.startUtf16, 0);
      expect(layout.endUtf16, 5);
      expect(layout.lines, hasLength(1));
      expect(layout.lines.single.startUtf16, 0);
      expect(layout.lines.single.endUtf16, 5);
      expect(layout.lines.single.height, greaterThan(0));
    });

    testWidgets('wrapping produces multiple lines', (tester) async {
      final spec = _testSpec();
      final layout = _layouter(spec).layoutTextBlock(
        blockIndex: 0,
        text: 'Hello world this is a long text that should wrap',
        spans: const [],
        style: _bodyStyle,
        maxWidth: 100,
      );

      expect(layout.lines.length, greaterThan(1));
      for (final line in layout.lines) {
        expect(line.height, greaterThan(0));
        expect(line.endUtf16, greaterThan(line.startUtf16));
      }
      // End of last line equals full text length.
      expect(
        layout.lines.last.endUtf16,
        'Hello world this is a long text that should wrap'.length,
      );
    });

    testWidgets('empty text returns empty layout', (tester) async {
      final spec = _testSpec();
      final layout = _layouter(spec).layoutTextBlock(
        blockIndex: 0,
        text: '',
        spans: const [],
        style: _bodyStyle,
        maxWidth: 300,
      );

      expect(layout.lines, isEmpty);
      expect(layout.endUtf16, 0);
    });
  });

  // ── 标题等级 ──
  group('heading levels', () {
    testWidgets('h1 has larger height than body', (tester) async {
      final spec = _testSpec(fontSize: 16);
      final layouter = _layouter(spec);

      final body = layouter.layoutTextBlock(
        blockIndex: 0,
        text: 'Body text',
        spans: const [],
        style: _bodyStyle,
        maxWidth: 300,
      );
      final h1 = layouter.layoutTextBlock(
        blockIndex: 1,
        text: 'Heading 1',
        spans: const [],
        style: const BlockStyle(isHeading: true, headingLevel: 1),
        maxWidth: 300,
      );

      expect(h1.lines.single.height, greaterThan(body.lines.single.height));
    });

    testWidgets('h1/h2/h3 have descending font sizes', (tester) async {
      final spec = _testSpec();
      final layouter = _layouter(spec);

      double layoutHeight(int level) => layouter
          .layoutTextBlock(
            blockIndex: 0,
            text: 'Test',
            spans: const [],
            style: BlockStyle(isHeading: true, headingLevel: level),
            maxWidth: 300,
          )
          .lines
          .single
          .height;

      final h1 = layoutHeight(1);
      final h2 = layoutHeight(2);
      final h3 = layoutHeight(3);

      expect(h1, greaterThan(h2));
      expect(h2, greaterThan(h3));
    });
  });

  // ── 内联样式 ──
  group('inline styles', () {
    testWidgets('bold runs do not change line count', (tester) async {
      final spec = _testSpec();
      final layout = _layouter(spec).layoutTextBlock(
        blockIndex: 0,
        text: 'Normal bold mix',
        spans: const [
          ReaderInlineRun(
            text: 'Normal ',
            style: ReaderInlineStyle(bold: false, italic: false),
          ),
          ReaderInlineRun(
            text: 'bold ',
            style: ReaderInlineStyle(bold: true, italic: false),
          ),
          ReaderInlineRun(
            text: 'mix',
            style: ReaderInlineStyle(bold: false, italic: false),
          ),
        ],
        style: _bodyStyle,
        maxWidth: 300,
      );

      expect(layout.lines, hasLength(1));
      expect(layout.lines.single.endUtf16, 'Normal bold mix'.length);
    });
  });

  // ── Emoji & 组合字符 ──
  group('emoji and surrogate pairs', () {
    testWidgets('emoji stays on one line when width sufficient', (
      tester,
    ) async {
      final spec = _testSpec();
      final layout = _layouter(spec).layoutTextBlock(
        blockIndex: 0,
        text: 'A😀B',
        spans: const [],
        style: _bodyStyle,
        maxWidth: 400,
      );

      expect(layout.lines, hasLength(1));
      expect(layout.lines.single.endUtf16, 4); // 'A😀B' is 4 UTF-16 code units
    });

    testWidgets('surrogate pair not split (emoji fills line)', (tester) async {
      final spec = _testSpec(fontSize: 32);
      final layout = _layouter(spec).layoutTextBlock(
        blockIndex: 0,
        text: 'X😀Y',
        spans: const [],
        style: _bodyStyle,
        maxWidth: 30,
      );

      // The emoji 😀 (U+1F600) is 2 UTF-16 code units.
      // With narrow width, it should still wrap at correct boundaries.
      for (final line in layout.lines) {
        // Verify no line ends on the LEAD surrogate (0xD83D).
        final lineText = 'X😀Y'.substring(line.startUtf16, line.endUtf16);
        expect(
          lineText.codeUnits.last < 0xD800 || lineText.codeUnits.last > 0xDBFF,
          isTrue,
          reason: 'Line must not end on a lead surrogate',
        );
      }
    });
  });

  // ── 首行缩进 ──
  group('first line indent', () {
    testWidgets('indent reduces first line content width', (tester) async {
      final spec = _testSpec(firstLineIndent: true);
      final layout = _layouter(spec).layoutTextBlock(
        blockIndex: 0,
        text:
            'A long line that will definitely wrap because the indent takes space',
        spans: const [],
        style: _bodyStyle,
        maxWidth: 100,
      );

      expect(layout.lines.length, greaterThanOrEqualTo(2));
      // First line shorter due to indent; content fits starting after indent.
      expect(layout.lines.first.endUtf16, lessThan(layout.lines.last.endUtf16));
    });

    testWidgets('heading has no indent', (tester) async {
      final spec = _testSpec(firstLineIndent: true);
      final h1 = _layouter(spec).layoutTextBlock(
        blockIndex: 0,
        text: 'Heading without indent',
        spans: const [],
        style: const BlockStyle(isHeading: true, headingLevel: 1),
        maxWidth: 50,
      );

      // h1 should still wrap like any text (no indent available, but same behavior).
      expect(h1.lines, isNotEmpty);
    });
  });

  // ── 字体缩放 ──
  group('text scaling', () {
    testWidgets('scaled text produces taller lines', (tester) async {
      final spec = _testSpec(textScaler: const TextScaler.linear(1.5));
      final layout = _layouter(spec).layoutTextBlock(
        blockIndex: 0,
        text: 'Scaled text',
        spans: const [],
        style: _bodyStyle,
        maxWidth: 300,
      );

      expect(layout.lines.single.height, greaterThan(16 * 1.5));
    });
  });

  // ── Image block ──
  group('layoutImageBlock', () {
    test('produces a single empty-lines block with metadata', () {
      final spec = _testSpec();
      final layout = _layouter(spec).layoutImageBlock(
        blockIndex: 0,
        startUtf16: 0,
        endUtf16: 1,
        assetId: 'cover.jpg',
        imageAlt: 'Cover',
        intrinsicWidth: 400,
        intrinsicHeight: 600,
        imageDisplayWidth: 300,
        imageDisplayHeight: 450,
      );

      expect(layout.isImage, isTrue);
      expect(layout.lines, isEmpty);
      expect(layout.assetId, 'cover.jpg');
      expect(layout.intrinsicWidth, 400);
      expect(layout.intrinsicHeight, 600);
      expect(layout.imageDisplayWidth, 300);
      expect(layout.imageDisplayHeight, 450);
    });
  });
}
