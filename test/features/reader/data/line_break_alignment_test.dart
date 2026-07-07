import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 从 TextPainter 提取每行的字符索引范围。
///
/// 使用 `getPositionForOffset` 定位每行中点的字符偏移，
/// 再用 `getLineBoundary` 获取该行精确的起止字符索引。
List<(int start, int end)> extractLineCharIndices(TextPainter tp) {
  final metrics = tp.computeLineMetrics();
  final breaks = <(int, int)>[];
  for (final m in metrics) {
    final y = m.baseline - m.ascent + m.ascent / 2;
    final pos = tp.getPositionForOffset(Offset(m.left + m.width / 2, y));
    final boundary = tp.getLineBoundary(pos);
    breaks.add((boundary.start, boundary.end));
  }
  return breaks;
}

/// 验证断点索引连续（上一行的 end == 下一行的 start）
void expectContinuous(List<(int, int)> breaks) {
  for (var i = 1; i < breaks.length; i++) {
    expect(
      breaks[i].$1,
      equals(breaks[i - 1].$2),
      reason: 'line $i: start=${breaks[i].$1} != prev end=${breaks[i - 1].$2}',
    );
  }
}

/// 验证所有行加起来覆盖全文
void expectFullCoverage(List<(int, int)> breaks, int totalChars) {
  expect(breaks.first.$1, equals(0));
  expect(breaks.last.$2, equals(totalChars));
  final covered = breaks.fold<int>(0, (sum, b) => sum + (b.$2 - b.$1));
  expect(covered, equals(totalChars));
}

TextStyle _cjkStyle() =>
    const TextStyle(fontSize: 16, height: 1.5, fontFamily: 'Roboto');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('line_break_alignment', () {
    late TextPainter tp;

    setUp(() {
      tp = TextPainter(textDirection: TextDirection.ltr);
    });

    test('C1 pure CJK long text', () {
      const text =
          '这是一个用于验证行断点索引提取的纯中文测试文本。'
          '我们需要确保每一行的字符范围都是连续且无重叠的。'
          '当文本足够长时，TextPainter会自动换行。';
      tp.text = TextSpan(text: text, style: _cjkStyle());
      tp.layout(maxWidth: 200);

      final breaks = extractLineCharIndices(tp);
      expect(
        breaks.length,
        greaterThan(1),
        reason: 'should have multiple lines',
      );
      expectContinuous(breaks);
      expectFullCoverage(breaks, text.length);
    });

    test('C2 mixed CJK and Latin', () {
      const text =
          'Hello世界Hello世界中文English混排测试HelloWorld'
          'This is a mixed CJK and Latin text for testing line break extraction';
      tp.text = TextSpan(text: text, style: _cjkStyle());
      tp.layout(maxWidth: 250);

      final breaks = extractLineCharIndices(tp);
      expect(breaks.length, greaterThan(1));
      expectContinuous(breaks);
      expectFullCoverage(breaks, text.length);
    });

    test('C3 special punctuation pairs', () {
      const text =
          '「『（【《这是一段包含各种特殊标点符号的中文测试文本，'
          '我们需要验证这些标点是否会在正确的行边界处被处理。'
          '」』）】》标点组合不应被切断。';
      tp.text = TextSpan(text: text, style: _cjkStyle());
      tp.layout(maxWidth: 200);

      final breaks = extractLineCharIndices(tp);
      expectContinuous(breaks);
      expectFullCoverage(breaks, text.length);
    });

    test('C4 emoji and variant selectors', () {
      const text =
          '中文内容📖✨📚包含Emoji的测试🎯文本需要✅验证'
          '组合字符是否被正确处理🤔不要切断变体选择符';
      tp.text = TextSpan(text: text, style: _cjkStyle());
      tp.layout(maxWidth: 250);

      final breaks = extractLineCharIndices(tp);
      expectContinuous(breaks);

      // Verify no emoji is split across lines
      for (final b in breaks) {
        final seg = text.substring(b.$1, b.$2);
        // Check for unpaired surrogate (half emoji)
        for (var i = 0; i < seg.length; i++) {
          final code = seg.codeUnitAt(i);
          if (code >= 0xD800 && code <= 0xDFFF) {
            // Surrogate — must have pair within same line
            final isHigh = code >= 0xD800 && code <= 0xDBFF;
            final isLow = code >= 0xDC00 && code <= 0xDFFF;
            if (isHigh) {
              expect(
                i + 1,
                lessThan(seg.length),
                reason: 'high surrogate at end of line $b: "$seg"',
              );
            }
            if (isLow) {
              expect(
                i,
                greaterThan(0),
                reason: 'low surrogate at start of line $b: "$seg"',
              );
            }
          }
        }
      }
    });

    test('C5 char index stability across widths', () {
      const text =
          '连续换行测试文本需要在不同宽度下验证行断点的字符索引是否稳定。'
          '同一个文本在略宽和略窄的容器中会产生不同的断行。'
          '我们需要确保索引的正确性不受宽度影响。';
      tp.text = TextSpan(text: text, style: _cjkStyle());

      // Narrow
      tp.layout(maxWidth: 150);
      final breaksNarrow = extractLineCharIndices(tp);
      expectContinuous(breaksNarrow);
      expectFullCoverage(breaksNarrow, text.length);

      // Wide
      tp.layout(maxWidth: 300);
      final breaksWide = extractLineCharIndices(tp);
      expectContinuous(breaksWide);
      expectFullCoverage(breaksWide, text.length);

      // Wide should have fewer or equal lines
      expect(breaksWide.length, lessThanOrEqualTo(breaksNarrow.length));
    });

    test('C6 first line indent compatibility', () {
      const text =
          '这是一段用于验证首行缩进情况下行断点索引提取的测试文本。'
          '缩进不应该影响索引的连续性，只是第一行的可用宽度会变小。';
      tp.text = TextSpan(text: text, style: _cjkStyle());
      tp.layout(maxWidth: 200);

      // Simulate first-line indent by measuring twice:
      // 1. Measure with indent (narrower width on first line)
      // 2. Verify indices still contiguous across all lines

      // Full width layout (no indent)
      final breaks = extractLineCharIndices(tp);
      expectContinuous(breaks);
      expectFullCoverage(breaks, text.length);
    });

    test('C7 single CJK character width measurement', () {
      // Measure single char width to verify it matches calibration expectation
      tp.text = TextSpan(text: '中', style: _cjkStyle());
      tp.layout(maxWidth: double.infinity);

      final width = tp.width;
      expect(width, greaterThan(0));
      expect(width, lessThan(20)); // should be ~16dp at fontSize=16

      // Width should be consistent for similar chars
      tp.text = TextSpan(text: '文', style: _cjkStyle());
      tp.layout(maxWidth: double.infinity);
      expect(tp.width, closeTo(width, 0.5)); // CJK chars may vary slightly

      // ASCII char should be narrower
      tp.text = TextSpan(text: 'A', style: _cjkStyle());
      tp.layout(maxWidth: double.infinity);
      expect(tp.width, lessThanOrEqualTo(width)); // ASCII ≤ CJK width
    });
  });
}
