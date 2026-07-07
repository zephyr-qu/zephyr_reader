import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/data/typeset_calibrator.dart';
import 'package:zephyr_reader/features/reader/rendering/reader_render_config.dart';

/// Inline version of _measureSliceLayout for CI use.
({int lines, double height}) _measureSliceLayout({
  required String text,
  required TextStyle style,
  required double maxWidth,
  double firstLineIndentPx = 0,
}) {
  if (text.isEmpty) return (lines: 0, height: 0.0);

  final tp = TextPainter(
    textDirection: TextDirection.ltr,
    textHeightBehavior: ReaderRenderConfig.textHeightBehavior,
  );

  if (firstLineIndentPx <= 0) {
    tp.text = TextSpan(text: text, style: style);
    tp.layout(maxWidth: maxWidth);
    return (lines: tp.computeLineMetrics().length, height: tp.height);
  }

  final narrowWidth = (maxWidth - firstLineIndentPx).clamp(1.0, maxWidth);
  var firstLineChars = text.length;
  for (var n = 1; n <= text.length; n++) {
    tp.text = TextSpan(text: text.substring(0, n), style: style);
    tp.layout(maxWidth: narrowWidth);
    if (tp.computeLineMetrics().length > 1) {
      firstLineChars = n - 1;
      break;
    }
  }
  if (firstLineChars <= 0) firstLineChars = 1;
  if (firstLineChars >= text.length) {
    tp.text = TextSpan(text: text, style: style);
    tp.layout(maxWidth: narrowWidth);
    return (lines: tp.computeLineMetrics().length, height: tp.height);
  }

  tp.text = TextSpan(text: text.substring(0, firstLineChars), style: style);
  tp.layout(maxWidth: narrowWidth);
  final firstHeight = tp.height;

  final remainder = text.substring(firstLineChars);
  tp.text = TextSpan(text: remainder, style: style);
  tp.layout(maxWidth: maxWidth);
  return (
    lines: 1 + tp.computeLineMetrics().length,
    height: firstHeight + tp.height,
  );
}

const _sampleCjk =
    '这是一段用于验收统一测量指纹的中文文本。'
    '包含足够长度以产生多行断行，用于对比 Rust 估算与 TextPainter 实际行数。'
    'End.';

const _params = TypesetMeasureParams(
  width: 360,
  height: 640,
  pagePadding: 16,
  contentVerticalPadding: 20,
  fontSize: 16,
  lineHeight: 1.5,
  letterSpacing: 0,
  fontFamily: 'Roboto',
  devicePixelRatio: 1.0,
  baselineAlign: true,
  firstLineIndentChars: 2,
);

const _dpr = 1.0;
const _pageWidthPx = (360 - 32); // (width - 2*padding) * dpr
const _fontSizePx = 16;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LayoutFingerprint alignment', () {
    late CalibrationData fingerprint;

    setUp(() {
      fingerprint = measureLayoutFingerprint(_params);
    });

    test('C1 TextPainter vs Rust estimate within 1 line', () {
      final textStyle = const TextStyle(
        fontSize: 16,
        fontFamily: 'Roboto',
        height: 1.5,
      );

      final measured = _measureSliceLayout(
        text: _sampleCjk,
        style: textStyle,
        maxWidth: _params.availableContentWidthDp,
        firstLineIndentPx: 32.0, // 2 chars * 16px
      );

      final rustLines = estimateRustLinesForText(
        text: _sampleCjk,
        applyFirstLineIndent: true,
        cjkWidthPx: fingerprint.cjkWidth * _dpr,
        pageWidthPx: _pageWidthPx,
        fontSizePx: _fontSizePx,
        effectiveLineWidthRatio: fingerprint.effectiveLineWidthRatio,
      );

      final delta = (measured.lines - rustLines).abs();
      expect(
        delta,
        lessThanOrEqualTo(1),
        reason: 'TextPainter=${measured.lines} vs Rust=$rustLines must be ≤1',
      );
    });

    test('C2 wider ratio produces fewer estimated lines', () {
      final linesNarrow = estimateRustLinesForText(
        text: _sampleCjk,
        applyFirstLineIndent: true,
        cjkWidthPx: fingerprint.cjkWidth * _dpr,
        pageWidthPx: _pageWidthPx,
        fontSizePx: _fontSizePx,
        effectiveLineWidthRatio: 0.90,
      );
      final linesWide = estimateRustLinesForText(
        text: _sampleCjk,
        applyFirstLineIndent: true,
        cjkWidthPx: fingerprint.cjkWidth * _dpr,
        pageWidthPx: _pageWidthPx,
        fontSizePx: _fontSizePx,
        effectiveLineWidthRatio: 0.99,
      );

      expect(
        linesWide,
        lessThanOrEqualTo(linesNarrow),
        reason:
            'wider(0.99)=$linesWide should be <= narrower(0.90)=$linesNarrow',
      );
    });

    test('C3 firstLineIndent increases line count', () {
      final linesNoIndent = estimateRustLinesForText(
        text: _sampleCjk,
        applyFirstLineIndent: false,
        cjkWidthPx: fingerprint.cjkWidth * _dpr,
        pageWidthPx: _pageWidthPx,
        fontSizePx: _fontSizePx,
        effectiveLineWidthRatio: fingerprint.effectiveLineWidthRatio,
      );
      final linesWithIndent = estimateRustLinesForText(
        text: _sampleCjk,
        applyFirstLineIndent: true,
        cjkWidthPx: fingerprint.cjkWidth * _dpr,
        pageWidthPx: _pageWidthPx,
        fontSizePx: _fontSizePx,
        effectiveLineWidthRatio: fingerprint.effectiveLineWidthRatio,
      );

      expect(
        linesWithIndent,
        greaterThanOrEqualTo(linesNoIndent),
        reason: 'indent=$linesWithIndent should be >= noIndent=$linesNoIndent',
      );
    });

    test('C4 buildTypesetConfig passes ratio to Rust config', () {
      final config = buildTypesetConfig(
        width: 360,
        height: 640,
        fontSize: 16,
        lineHeight: 1.5,
        calibration: fingerprint,
      );

      expect(config.calibration, isNotNull);
      expect(
        config.calibration!.effectiveLineWidthRatio,
        closeTo(fingerprint.effectiveLineWidthRatio, 0.001),
      );
    });
  });
}
