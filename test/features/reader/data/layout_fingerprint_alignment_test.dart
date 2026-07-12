import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/data/page_overflow_diagnosis.dart';
import 'package:zephyr_reader/features/reader/data/typeset_calibrator.dart';
import 'package:zephyr_reader/features/reader/rendering/reader_render_config.dart';

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
      final strut = const StrutStyle(
        fontSize: 16,
        height: 1.5,
        forceStrutHeight: true,
        fontFamily: 'Roboto',
      );

      final measured = measureSliceLayout(
        text: _sampleCjk,
        style: textStyle,
        strutStyle: strut,
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

      // Factor diagnosis on a synthetic page using measured heights
      final bodyH = (_params.height - 2 * _params.contentVerticalPadding).clamp(
        100.0,
        _params.height,
      );
      final diag = diagnosePageOverflow(
        PageOverflowMetrics(
          bodyHeightDp: bodyH,
          textHeightDp: measured.height,
          spacingHeightDp: 0,
          flutLines: measured.lines,
          rustEstLines: rustLines,
          flutLineHeightDp: fingerprint.lineHeightDp,
          rustLineHeightDp: fingerprint.lineHeightDp,
          rustPageHeightBudgetDp: bodyH,
        ),
      );
      // Single short sample should not overflow a full page
      expect(diag.cause, isNot(PageOverflowCause.pageHeightPadding));
      expect(measured.height, lessThan(bodyH));
    });

    test('C2 narrower glyphs produce more estimated lines', () {
      final linesNarrowGlyph = estimateRustLinesForText(
        text: _sampleCjk,
        applyFirstLineIndent: true,
        cjkWidthPx: fingerprint.cjkWidth * 1.15 * _dpr,
        pageWidthPx: _pageWidthPx,
        fontSizePx: _fontSizePx,
      );
      final linesWideGlyph = estimateRustLinesForText(
        text: _sampleCjk,
        applyFirstLineIndent: true,
        cjkWidthPx: fingerprint.cjkWidth * 0.85 * _dpr,
        pageWidthPx: _pageWidthPx,
        fontSizePx: _fontSizePx,
      );

      expect(
        linesWideGlyph,
        lessThanOrEqualTo(linesNarrowGlyph),
        reason:
            'narrowerGlyph=$linesWideGlyph should be <= widerGlyph=$linesNarrowGlyph',
      );
    });

    test('C2b mixed Latin uses ascii width not CJK (no inflate)', () {
      const mixed = 'Hello世界Hello世界English混排测试文本足够长触发多行';
      final asCjkOnly = estimateRustLinesForText(
        text: mixed,
        applyFirstLineIndent: false,
        cjkWidthPx: 16,
        pageWidthPx: 320,
        fontSizePx: 16,
        // force all-as-cjk by making ascii equally wide
        asciiWidthPx: 16,
      );
      final variable = estimateRustLinesForText(
        text: mixed,
        applyFirstLineIndent: false,
        cjkWidthPx: 16,
        pageWidthPx: 320,
        fontSizePx: 16,
        asciiWidthPx: 9.6,
      );
      expect(
        variable,
        lessThanOrEqualTo(asCjkOnly),
        reason: 'variable-width must not inflate Latin to CJK width',
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

    test('C5 full-page packing: diagnose classifies overflow factors', () {
      // Pack enough CJK to exceed body when Rust underestimates lines.
      final longCjk = _sampleCjk * 8;
      final textStyle = TextStyle(
        fontSize: _params.fontSize,
        fontFamily: _params.fontFamily,
        height: _params.lineHeight,
      );
      final strut = ReaderRenderConfig(
        textColor: const Color(0xFF000000),
        backgroundColor: const Color(0xFFFFFFFF),
        fontSize: _params.fontSize,
        lineHeight: _params.lineHeight,
        fontFamily: _params.fontFamily,
        letterSpacing: 0,
        paragraphSpacing: 0,
        pageMargin: 16,
        showVocabularyMark: false,
        vocabularyWords: const {},
        baselineAlign: true,
      ).buildStrutStyle();

      final measured = measureSliceLayout(
        text: longCjk,
        style: textStyle,
        strutStyle: strut,
        maxWidth: _params.availableContentWidthDp,
      );

      // Intentionally optimistic rust estimate (fewer lines) → charWidth
      final optimisticRustLines = (measured.lines - 3).clamp(1, measured.lines);
      final bodyH = measured.height - 48; // force overflow
      final diag = diagnosePageOverflow(
        PageOverflowMetrics(
          bodyHeightDp: bodyH,
          textHeightDp: measured.height,
          spacingHeightDp: 0,
          flutLines: measured.lines,
          rustEstLines: optimisticRustLines,
          flutLineHeightDp: fingerprint.lineHeightDp,
          rustLineHeightDp: fingerprint.lineHeightDp,
        ),
      );

      expect(diag.metrics.overflowDp, greaterThan(kOverflowOkDp));
      expect(
        diag.cause == PageOverflowCause.charWidthOrRatio ||
            diag.cause == PageOverflowCause.lineHeight ||
            diag.cause == PageOverflowCause.mixed,
        isTrue,
        reason: 'unexpected cause=${diag.cause} ${diag.summary}',
      );
    });
  });
}
