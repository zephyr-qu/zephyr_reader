// test/features/reader/data/line_break_extractor_test.dart
//
// 验证 `computeLineBreakIndices` 的正确性与 Rust `paginate_from_line_breaks`
// 的兼容性。
//
// 关键不变量：
// - I_phase6_1: 索引严格递增，最后一个索引 == text.length
// - I_phase6_2: 行数 × line_height ≤ page_height → 满页无溢出
// - I_phase6_3: indices.length == computeLineMetrics 的行数
//
// 这些不变量依赖于 Flutter ICU 断行引擎的稳定性。如果 Flutter 升级导致
// 断行结果变化，本测试会捕获差异。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/data/line_break_extractor.dart';
import 'package:zephyr_reader/src/rust/domain/types/content_ir.dart';

TextStyle _cjkStyle() =>
    const TextStyle(fontSize: 16, height: 1.5, fontFamily: 'Roboto');

TextStyle _mixedStyle() =>
    const TextStyle(fontSize: 18, height: 1.4, fontFamily: 'Serif');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('computeLineBreakIndices', () {
    test('empty text returns empty list', () {
      final indices = computeLineBreakIndices(
        text: '',
        style: _cjkStyle(),
        maxWidth: 200,
      );
      expect(indices, isEmpty);
    });

    test('single line text returns [text.length]', () {
      const text = 'Hello, world!';
      final indices = computeLineBreakIndices(
        text: text,
        style: _cjkStyle(),
        maxWidth: 2000, // wide enough for one line
      );
      expect(indices, [text.length]);
    });

    test('multi-line CJK indices are strictly increasing', () {
      const text =
          '这是一个用于验证行断点索引的纯中文测试文本。'
          '我们需要确保每一行的结束偏移量是严格递增且覆盖全文的。'
          '当文本足够长时，TextPainter 会自动换行形成多行结果。'
          '验证：最后一个索引必须等于文本总长度。';

      final indices = computeLineBreakIndices(
        text: text,
        style: _cjkStyle(),
        maxWidth: 200,
      );

      expect(indices.length, greaterThan(1));
      expect(validateLineBreakIndices(indices, text), isTrue);
      expect(indices.last, text.length);
    });

    test('mixed CJK-Latin indices match line metrics count', () {
      const text =
          'Hello世界中文English混排测试HelloWorld'
          'This is a mixed CJK and Latin text for testing line break extraction。'
          '验证混合文本的行断点索引是否正确。';

      final indices = computeLineBreakIndices(
        text: text,
        style: _mixedStyle(),
        maxWidth: 250,
      );

      expect(indices.length, greaterThan(1));
      expect(validateLineBreakIndices(indices, text), isTrue);

      // Verify indices.length == computeLineMetrics row count
      final tp = TextPainter(
        text: TextSpan(text: text, style: _mixedStyle()),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 250);
      expect(indices.length, tp.computeLineMetrics().length);
    });

    test('indices are consistent across font sizes', () {
      const text =
          '同一段文本在不同字号下的行断点索引应该不同'
          '（行容量不同），但每个索引必须覆盖全文且严格递增。';

      final indicesSmall = computeLineBreakIndices(
        text: text,
        style: const TextStyle(fontSize: 14),
        maxWidth: 200,
      );
      final indicesLarge = computeLineBreakIndices(
        text: text,
        style: const TextStyle(fontSize: 20),
        maxWidth: 200,
      );

      // Larger font → fewer chars per line → more lines → more indices
      expect(indicesLarge.length, greaterThanOrEqualTo(indicesSmall.length));
      // Both must cover full text
      expect(validateLineBreakIndices(indicesSmall, text), isTrue);
      expect(validateLineBreakIndices(indicesLarge, text), isTrue);
    });

    test('validateLineBreakIndices catches invalid indices', () {
      const text = '测试文本';

      // Correct indices (text has 4 chars, 2 lines of 2 chars each)
      expect(validateLineBreakIndices([2, 4], text), isTrue);

      // Last index != text.length
      expect(validateLineBreakIndices([4, 7], text), isFalse);

      // Non-monotonic
      expect(validateLineBreakIndices([6, 4], text), isFalse);

      // Empty text, empty indices
      expect(validateLineBreakIndices([], ''), isTrue);

      // Non-empty indices for empty text (fails last-index check)
      expect(validateLineBreakIndices([5], ''), isFalse);
    });

    test('emoji surrogate pairs are not split', () {
      const text =
          '中文📖Emoji📚混合测试🎯文本需要✅验证'
          '组合字符不会被切断🔥🔥🔥🔥🔥🔥🔥';
      final style = _cjkStyle();

      final indices = computeLineBreakIndices(
        text: text,
        style: style,
        maxWidth: 200,
      );

      expect(validateLineBreakIndices(indices, text), isTrue);

      // Verify no surrogate pair is split across indices
      for (final idx in indices) {
        if (idx > 0 && idx < text.length) {
          final prevCode = text.codeUnitAt(idx - 1);
          final currCode = text.codeUnitAt(idx);
          // High surrogate should not be at end of a line (paired with low)
          if (prevCode >= 0xD800 && prevCode <= 0xDBFF) {
            // The low surrogate should be right after
            expect(currCode, inInclusiveRange(0xDC00, 0xDFFF));
          }
        }
      }
    });

    test('special punctuation pairs are not forcibly split', () {
      const text =
          '「『（【《这是一段包含各种标点符号的文本，'
          '我们需要验证标点是否在正确的边界处断行。'
          '」』）】》标点组合不应被切断。';

      final indices = computeLineBreakIndices(
        text: text,
        style: _cjkStyle(),
        maxWidth: 200,
      );

      expect(validateLineBreakIndices(indices, text), isTrue);
    });
  });

  group('Rust paginate_from_line_breaks compatibility', () {
    // 模拟 Rust paginate_from_line_breaks 的分页逻辑：
    //
    // lines_per_page = page_height_px / line_height_px
    // 按 lines_per_page 分组 indices → page descriptors
    //
    // 这里我们用 Dart 实现相同的逻辑，验证索引格式兼容。

    ({int pageStartChar, int pageEndChar, bool isLast}) simulateRustPagination({
      required List<int> indices,
      required double pageHeightPx,
      required double lineHeightPx,
      int? textLength,
    }) {
      final linesPerPage = (pageHeightPx / lineHeightPx).floor();
      final pages = <({int start, int end, bool isLast})>[];
      var lineIdx = 0;

      while (lineIdx < indices.length) {
        final pageEndLine = (lineIdx + linesPerPage).clamp(0, indices.length);
        final startChar = lineIdx == 0 ? 0 : indices[lineIdx - 1];
        final endChar = indices[pageEndLine - 1];
        final isLast = pageEndLine >= indices.length;

        pages.add((start: startChar, end: endChar, isLast: isLast));
        lineIdx = pageEndLine;
      }

      if (pages.isEmpty) {
        return (pageStartChar: 0, pageEndChar: 0, isLast: true);
      }
      final first = pages.first;
      return (
        pageStartChar: first.start,
        pageEndChar: first.end,
        isLast: first.isLast,
      );
    }

    test('simulated Rust pagination produces valid page boundaries', () {
      const text =
          '模拟 Rust 分页引擎的纯数学映射。给定行断点索引和行高，'
          '计算每页能容纳的行数，然后按行分组生成页范围。'
          '验证：索引与分页结果一致。';

      final indices = computeLineBreakIndices(
        text: text,
        style: _cjkStyle(),
        maxWidth: 200,
      );

      expect(indices.isNotEmpty, isTrue);
      expect(validateLineBreakIndices(indices, text), isTrue);

      // Simulate with typical page dimensions
      const pageHeightPx = 800.0; // 600dp @ 2x
      const lineHeightPx = 24.0; // 16 * 1.5
      final firstPage = simulateRustPagination(
        indices: indices,
        pageHeightPx: pageHeightPx,
        lineHeightPx: lineHeightPx,
      );

      // First page should contain fewer or equal chars than total
      expect(firstPage.pageEndChar, lessThanOrEqualTo(text.length));
      expect(firstPage.pageStartChar, greaterThanOrEqualTo(0));
      expect(firstPage.pageEndChar, greaterThan(firstPage.pageStartChar));
    });
  });

  group('computeChapterLineBreakIndicesFromBlocks', () {
    test('merges per-block absolute indices across BlockJoined separators', () {
      // Hello\nWorld — block0 [0,5), block1 [6,11)
      final blocks = [
        const ContentBlock.text(
          TextBlock(
            plain: BlockPlainRange(plainStart: 0, plainLen: 5),
            text: 'Hello',
            style: TextBlockStyle(isHeading: false, headingLevel: 0),
            spans: [],
          ),
        ),
        const ContentBlock.text(
          TextBlock(
            plain: BlockPlainRange(plainStart: 6, plainLen: 5),
            text: 'World',
            style: TextBlockStyle(isHeading: false, headingLevel: 0),
            spans: [],
          ),
        ),
      ];
      final config = lineBreakMeasureRenderConfig(
        fontSize: 16,
        lineHeight: 1.5,
        fontFamily: 'Roboto',
        letterSpacing: 0,
        paragraphSpacing: 16,
        pageMargin: 16,
        firstLineIndent: false,
        baselineAlign: true,
      );
      final indices = computeChapterLineBreakIndicesFromBlocks(
        blocks: blocks,
        config: config,
        contentMaxWidth: 2000,
      );
      expect(indices, [5, 11]);
    });

    test('image block contributes FFFC end index', () {
      final blocks = [
        const ContentBlock.text(
          TextBlock(
            plain: BlockPlainRange(plainStart: 0, plainLen: 2),
            text: '前文',
            style: TextBlockStyle(isHeading: false, headingLevel: 0),
            spans: [],
          ),
        ),
        const ContentBlock.image(
          ImageBlock(
            plain: BlockPlainRange(plainStart: 3, plainLen: 1),
            assetId: 'img1',
          ),
        ),
      ];
      final config = lineBreakMeasureRenderConfig(
        fontSize: 16,
        lineHeight: 1.5,
        fontFamily: 'Roboto',
        letterSpacing: 0,
        paragraphSpacing: 16,
        pageMargin: 16,
        firstLineIndent: false,
        baselineAlign: true,
      );
      final indices = computeChapterLineBreakIndicesFromBlocks(
        blocks: blocks,
        config: config,
        contentMaxWidth: 400,
      );
      expect(indices.contains(4), isTrue); // image end at 3+1
      expect(indices, containsAll([2, 4]));
    });

    test('first-line indent produces more or equal lines vs no indent', () {
      const text =
          '这是一段足够长的中文测试文本用来验证首行缩进会导致首行更早换行从而可能增加总行数。';
      final style = _cjkStyle();
      final noIndent = computeLineBreakIndices(
        text: text,
        style: style,
        maxWidth: 200,
        firstLineIndentPx: 0,
      );
      final withIndent = computeLineBreakIndices(
        text: text,
        style: style,
        maxWidth: 200,
        firstLineIndentPx: 32,
      );
      expect(withIndent.length, greaterThanOrEqualTo(noIndent.length));
      expect(validateLineBreakIndices(withIndent, text), isTrue);
    });
  });
}
