import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/data/line_break_extractor.dart';
import 'package:zephyr_reader/features/reader/flutter_pagination/flutter_block_paginator.dart';
import 'package:zephyr_reader/features/reader/flutter_pagination/slice_rich_spans.dart';
import 'package:zephyr_reader/src/rust/domain/types/content_ir.dart';
import 'package:zephyr_reader/src/rust/domain/types/rich_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('sliceRichSpans', () {
    test('clips mid-span and preserves style/link', () {
      final spans = [
        const RichTextSpan.styled(
          SpanStyle.plain,
          RichTextSpanData(text: 'ab'),
        ),
        const RichTextSpan.styled(
          SpanStyle.bold,
          RichTextSpanData(text: 'cdef'),
        ),
        const RichTextSpan.link(
          data: RichTextSpanData(text: 'gh'),
          url: 'https://x',
        ),
      ];
      // [2, 6) → "cdef"
      final mid = sliceRichSpans(spans, start: 2, len: 4);
      expect(mid, hasLength(1));
      expect(richSpanText(mid.single), 'cdef');
      expect(
        mid.single.when(styled: (s, _) => s, link: (_, _) => null),
        SpanStyle.bold,
      );

      // [1, 7) → "b" + "cdef" + "g"
      final cross = sliceRichSpans(spans, start: 1, len: 6);
      expect(cross.map(richSpanText).join(), 'bcdefg');
      expect(cross, hasLength(3));
      expect(
        cross[2].when(styled: (_, _) => null, link: (_, url) => url),
        'https://x',
      );
    });

    test('empty range yields empty', () {
      expect(
        sliceRichSpans(const [], start: 0, len: 1),
        isEmpty,
      );
      expect(
        sliceRichSpans([
          const RichTextSpan.styled(
            SpanStyle.italic,
            RichTextSpanData(text: 'x'),
          ),
        ], start: 0, len: 0),
        isEmpty,
      );
    });
  });

  test('paginate keeps clipped spans on text slices', () {
    final config = lineBreakMeasureRenderConfig(
      fontSize: 16,
      lineHeight: 1.5,
      fontFamily: 'Roboto',
      letterSpacing: 0,
      paragraphSpacing: 8,
      pageMargin: 16,
      firstLineIndent: false,
      baselineAlign: true,
    );
    const text = '粗体强调普通';
    final ir = const ChapterContentIr(
      blocks: [
        ContentBlock.text(
          TextBlock(
            plain: BlockPlainRange(plainStart: 0, plainLen: text.length),
            text: text,
            style: TextBlockStyle(isHeading: false, headingLevel: 0),
            spans: [
              RichTextSpan.styled(
                SpanStyle.bold,
                RichTextSpanData(text: '粗体'),
              ),
              RichTextSpan.styled(
                SpanStyle.italic,
                RichTextSpanData(text: '强调'),
              ),
              RichTextSpan.styled(
                SpanStyle.plain,
                RichTextSpanData(text: '普通'),
              ),
            ],
          ),
        ),
      ],
      plainText: text,
    );

    final pages = FlutterBlockPaginator.paginate(
      ir,
      config: config,
      contentWidthDp: 300,
      contentHeightDp: 400,
    );

    expect(pages, hasLength(1));
    final slice = pages.single.slices.single;
    expect(slice.spans, isNotEmpty);
    expect(slice.spans.map(richSpanText).join(), text);
    expect(
      slice.spans.first.when(styled: (s, _) => s, link: (_, _) => null),
      SpanStyle.bold,
    );
  });
}
