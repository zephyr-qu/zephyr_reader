import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/data/page_overflow_diagnosis.dart';

PageOverflowMetrics _m({
  double bodyHeightDp = 400,
  double textHeightDp = 400,
  double spacingHeightDp = 0,
  int flutLines = 20,
  int rustEstLines = 20,
  double flutLineHeightDp = 24,
  double rustLineHeightDp = 24,
  double? rustPageHeightBudgetDp,
  double contentVerticalPaddingDp = 20,
}) {
  return PageOverflowMetrics(
    bodyHeightDp: bodyHeightDp,
    textHeightDp: textHeightDp,
    spacingHeightDp: spacingHeightDp,
    flutLines: flutLines,
    rustEstLines: rustEstLines,
    flutLineHeightDp: flutLineHeightDp,
    rustLineHeightDp: rustLineHeightDp,
    rustPageHeightBudgetDp: rustPageHeightBudgetDp,
    contentVerticalPaddingDp: contentVerticalPaddingDp,
  );
}

void main() {
  group('diagnosePageOverflow', () {
    test('ok when overflow ≤ 0.5 and underfill small', () {
      final d = diagnosePageOverflow(
        _m(bodyHeightDp: 400, textHeightDp: 399.7, flutLines: 16, rustEstLines: 16),
      );
      expect(d.cause, PageOverflowCause.ok);
      expect(d.isOk, isTrue);
    });

    test('charWidthOrRatio when flutLines ≫ rust and overflow', () {
      // phase6 §5.3: flutLines=25 rustEstLines=22 overflow>0
      // overflow 故意避开 2×vPad(=40)，以免触发 pageHeight 启发
      final d = diagnosePageOverflow(
        _m(
          bodyHeightDp: 400,
          textHeightDp: 460,
          flutLines: 25,
          rustEstLines: 22,
          flutLineHeightDp: 18,
          rustLineHeightDp: 18,
        ),
      );
      expect(d.cause, PageOverflowCause.charWidthOrRatio);
      expect(d.toLogLine(), contains('cause=charWidthOrRatio'));
    });

    test('lineHeight when line counts match but text overflows', () {
      final d = diagnosePageOverflow(
        _m(
          bodyHeightDp: 400,
          textHeightDp: 430, // overflow 30，远离 2×vPad=40
          flutLines: 20,
          rustEstLines: 20,
          flutLineHeightDp: 22,
          rustLineHeightDp: 20,
        ),
      );
      expect(d.cause, PageOverflowCause.lineHeight);
    });

    test('paragraphSpacing when text fits but spacing pushes over', () {
      final d = diagnosePageOverflow(
        _m(
          bodyHeightDp: 400,
          textHeightDp: 380,
          spacingHeightDp: 48, // overflow 28
          flutLines: 16,
          rustEstLines: 16,
        ),
      );
      expect(d.cause, PageOverflowCause.paragraphSpacing);
      expect(d.summary, contains('spacing'));
    });

    test('pageHeightPadding when rust budget taller than body', () {
      final d = diagnosePageOverflow(
        _m(
          bodyHeightDp: 400,
          textHeightDp: 430,
          flutLines: 18,
          rustEstLines: 18,
          rustPageHeightBudgetDp: 440, // +40 ≈ 2×vPad
        ),
      );
      expect(d.cause, PageOverflowCause.pageHeightPadding);
    });

    test('pageHeightPadding heuristic when overflow ≈ 2×vPad', () {
      final d = diagnosePageOverflow(
        _m(
          bodyHeightDp: 400,
          textHeightDp: 440, // overflow 40 == 2*20
          flutLines: 18,
          rustEstLines: 18,
          flutLineHeightDp: 24,
          contentVerticalPaddingDp: 20,
        ),
      );
      expect(d.cause, PageOverflowCause.pageHeightPadding);
    });

    test('underfill when bottom blank exceeds 1.5 lines', () {
      final d = diagnosePageOverflow(
        _m(
          bodyHeightDp: 400,
          textHeightDp: 300, // underfill 100 > 24*1.5
          flutLines: 12,
          rustEstLines: 12,
          flutLineHeightDp: 24,
        ),
      );
      expect(d.cause, PageOverflowCause.underfill);
    });

    test('underfill + fewer flut lines still underfill (ICU 路径不误判字宽)', () {
      final d = diagnosePageOverflow(
        _m(
          bodyHeightDp: 400,
          textHeightDp: 280,
          flutLines: 10,
          rustEstLines: 14,
          flutLineHeightDp: 24,
        ),
      );
      expect(d.cause, PageOverflowCause.underfill);
      expect(d.summary, contains('行高预算'));
    });

    test('mixed when width drift and padding budget both hit', () {
      final d = diagnosePageOverflow(
        _m(
          bodyHeightDp: 400,
          textHeightDp: 480,
          flutLines: 26,
          rustEstLines: 22,
          rustPageHeightBudgetDp: 440,
        ),
      );
      expect(d.cause, PageOverflowCause.mixed);
      expect(d.summary, contains('charWidthOrRatio'));
      expect(d.summary, contains('pageHeightPadding'));
    });

    test('empty text page is emptyPage not underfill', () {
      final d = diagnosePageOverflow(
        _m(
          bodyHeightDp: 768,
          textHeightDp: 0,
          flutLines: 0,
          rustEstLines: 0,
        ),
      );
      expect(d.cause, PageOverflowCause.emptyPage);
    });
  });
}
