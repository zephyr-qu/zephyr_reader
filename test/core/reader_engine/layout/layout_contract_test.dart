import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zephyr_reader/core/reader_engine/layout/layout_spec.dart';
import 'package:zephyr_reader/core/reader_engine/layout/layout_key.dart';
import 'package:zephyr_reader/core/reader_engine/layout/block_layout.dart';
import 'package:zephyr_reader/core/reader_engine/layout/layout_snapshot.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/page_plan.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/packed_page.dart'
    show ReaderIrBlockLayout;
import 'package:zephyr_reader/core/reader_engine/shared/ir_types.dart';
import 'package:zephyr_reader/core/reader_engine/shared/pagination_params.dart';
import 'package:zephyr_reader/src/rust/pipeline/types.dart';

void main() {
  // ── LayoutSpec 工厂测试 ──
  group('LayoutSpec', () {
    test('fromPaginationParams preserves fields', () {
      final spec = LayoutSpec.fromPaginationParams(
        const PaginationParams(
          fontSize: 18,
          lineHeight: 1.6,
          width: 400,
          height: 600,
          padding: 24,
          fontFamily: 'serif',
        ),
      );
      expect(spec.fontSize, 18);
      expect(spec.lineHeight, 1.6);
      expect(spec.viewportWidth, 400);
      expect(spec.viewportHeight, 600);
      expect(spec.contentPadding, 24);
      expect(spec.fontFamily, 'serif');
    });

    test('contentWidth/contentHeight derive from viewport', () {
      final spec = const LayoutSpec(
        viewportWidth: 400,
        viewportHeight: 600,
        contentPadding: 20,
        fontFamily: 'sans-serif',
        fontSize: 16,
        lineHeight: 1.5,
        paragraphSpacing: 8,
      );
      expect(spec.contentWidth, closeTo(360, 0.01));
      expect(spec.contentHeight, closeTo(560, 0.01));
    });

    test('excludes visual-only properties', () {
      // LayoutSpec 应该没有 textColor、backgroundColor、vocabularyWords 等字段。
      final spec = const LayoutSpec(
        viewportWidth: 400,
        viewportHeight: 600,
        contentPadding: 20,
        fontFamily: 'sans-serif',
        fontSize: 16,
        lineHeight: 1.5,
        paragraphSpacing: 8,
      );
      // Verify it compiles and has layout fields only.
      expect(spec.textScaler, TextScaler.noScaling);
      expect(spec.baselineAlign, isTrue);
    });
  });

  // ── LayoutKey 一致性测试 ──
  group('LayoutKey', () {
    test('same spec produces same key', () {
      final spec = const LayoutSpec(
        viewportWidth: 400,
        viewportHeight: 600,
        contentPadding: 20,
        fontFamily: 'sans-serif',
        fontSize: 16,
        lineHeight: 1.5,
        paragraphSpacing: 8,
      );
      expect(LayoutKey.fromSpec(spec), LayoutKey.fromSpec(spec));
    });

    test('different fontSize produces different key', () {
      final a = const LayoutSpec(
        viewportWidth: 400,
        viewportHeight: 600,
        contentPadding: 20,
        fontFamily: 'sans-serif',
        fontSize: 16,
        lineHeight: 1.5,
        paragraphSpacing: 8,
      );
      final b = const LayoutSpec(
        viewportWidth: 400,
        viewportHeight: 600,
        contentPadding: 20,
        fontFamily: 'sans-serif',
        fontSize: 18,
        lineHeight: 1.5,
        paragraphSpacing: 8,
      );
      expect(LayoutKey.fromSpec(a), isNot(LayoutKey.fromSpec(b)));
    });

    test('different textScaler produces different key', () {
      final a = const LayoutSpec(
        viewportWidth: 400,
        viewportHeight: 600,
        contentPadding: 20,
        fontFamily: 'sans-serif',
        fontSize: 16,
        lineHeight: 1.5,
        paragraphSpacing: 8,
        textScaler: TextScaler.noScaling,
      );
      final b = const LayoutSpec(
        viewportWidth: 400,
        viewportHeight: 600,
        contentPadding: 20,
        fontFamily: 'sans-serif',
        fontSize: 16,
        lineHeight: 1.5,
        paragraphSpacing: 8,
        textScaler: TextScaler.linear(1.2),
      );
      expect(LayoutKey.fromSpec(a), isNot(LayoutKey.fromSpec(b)));
    });

    test('baselineAlign change produces different key', () {
      final a = const LayoutSpec(
        viewportWidth: 400,
        viewportHeight: 600,
        contentPadding: 20,
        fontFamily: 'sans-serif',
        fontSize: 16,
        lineHeight: 1.5,
        paragraphSpacing: 8,
        baselineAlign: true,
      );
      final b = const LayoutSpec(
        viewportWidth: 400,
        viewportHeight: 600,
        contentPadding: 20,
        fontFamily: 'sans-serif',
        fontSize: 16,
        lineHeight: 1.5,
        paragraphSpacing: 8,
        baselineAlign: false,
      );
      expect(LayoutKey.fromSpec(a), isNot(LayoutKey.fromSpec(b)));
    });
  });

  // ── BlockLayout 测试 ──
  group('BlockLayout', () {
    test('contentHeight sums line heights plus margins', () {
      final block = const BlockLayout(
        blockIndex: 0,
        startUtf16: 0,
        endUtf16: 10,
        margins: EdgeInsets.only(top: 4, bottom: 4),
        lines: [
          LineLayout(startUtf16: 0, endUtf16: 5, height: 24, baseline: 20),
          LineLayout(startUtf16: 5, endUtf16: 10, height: 24, baseline: 20),
        ],
      );
      // 24 + 24 + 4 + 4 = 56
      expect(block.contentHeight, closeTo(56, 0.01));
      expect(block.lineCount, 2);
    });

    test('empty lines block has zero content height', () {
      final block = const BlockLayout(
        blockIndex: 0,
        startUtf16: 0,
        endUtf16: 0,
        lines: [],
      );
      expect(block.contentHeight, 0);
      expect(block.lineCount, 0);
    });
  });

  // ── PagePlan 连续性 + Adapter 测试 ──
  group('PagePlan continuity', () {
    PagePlan makePage(int index, int start, int end) => PagePlan(
      pageIndex: index,
      startUtf16: start,
      endUtf16: end,
      fragments: const [],
    );

    test('continuous pages validate', () {
      final pages = [
        makePage(0, 0, 100),
        makePage(1, 100, 200),
        makePage(2, 200, 350),
      ];
      expect(PagePlanValidator.validateContinuity(pages), isNull);
      expect(PagePlanValidator.validateRanges(pages), isNull);
    });

    test('gap between pages fails continuity', () {
      final pages = [
        makePage(0, 0, 100),
        makePage(1, 110, 200), // gap: end 100 != start 110
      ];
      expect(PagePlanValidator.validateContinuity(pages), isNotNull);
    });

    test('overlap between pages fails continuity', () {
      final pages = [
        makePage(0, 0, 100),
        makePage(1, 95, 200), // overlap: end 100 > start 95
      ];
      expect(PagePlanValidator.validateContinuity(pages), isNotNull);
    });

    test('start > end fails range validation', () {
      final pages = [makePage(0, 100, 50)];
      expect(PagePlanValidator.validateRanges(pages), isNotNull);
    });

    test('empty fragment list validates', () {
      expect(PagePlanValidator.validateContinuity([]), isNull);
      expect(PagePlanValidator.validateRanges([]), isNull);
    });
  });

  group('PagePlan adapter', () {
    test('text PagePlan → PackedPage preserves offset range', () {
      final plan = const PagePlan(
        pageIndex: 0,
        startUtf16: 10,
        endUtf16: 50,
        fragments: [
          PageFragment.text(
            blockIndex: 0,
            startUtf16: 10,
            endUtf16: 30,
            text: 'Hello ',
            isBlockEnd: false,
          ),
          PageFragment.text(
            blockIndex: 0,
            startUtf16: 30,
            endUtf16: 50,
            text: 'world!',
            isBlockStart: false,
            isBlockEnd: true,
          ),
        ],
        usedHeight: 120,
        isLastPage: true,
      );

      final packed = plan.toPackedPage();

      expect(packed.pageIndex, 0);
      expect(packed.startOffset, 10);
      expect(packed.endOffset, 50);
      expect(packed.isLastPage, isTrue);
      expect(packed.slices, hasLength(2));
      expect(packed.slices[0].text, 'Hello ');
      expect(packed.slices[0].isBlockStart, isTrue);
      expect(packed.slices[0].isBlockEnd, isFalse);
      expect(packed.slices[1].text, 'world!');
      expect(packed.slices[1].isBlockStart, isFalse);
      expect(packed.slices[1].isBlockEnd, isTrue);
    });

    test('image PageFragment → PackedBlockSlice preserves intrinsic size', () {
      final fragment = const PageFragment.image(
        blockIndex: 1,
        startUtf16: 50,
        endUtf16: 51,
        assetId: 'cover.jpg',
        imageLayout: ReaderIrBlockLayout.inlineContain,
        imageAlt: 'Cover',
        intrinsicWidth: 400,
        intrinsicHeight: 600,
      );

      final slice = fragment.toPackedSlice();

      expect(slice.isImage, isTrue);
      expect(slice.assetId, 'cover.jpg');
      expect(slice.imageAlt, 'Cover');
      expect(slice.imageIntrinsicWidth, 400);
      expect(slice.imageIntrinsicHeight, 600);
      expect(slice.imageLayout, ReaderIrBlockLayout.inlineContain);
    });

    test('adapter round-trip preserves range for empty fragments', () {
      final plan = const PagePlan(
        pageIndex: 0,
        startUtf16: 0,
        endUtf16: 0,
        fragments: [],
        isLastPage: true,
      );

      final packed = plan.toPackedPage();

      expect(packed.startOffset, 0);
      expect(packed.endOffset, 0);
      expect(packed.slices, isEmpty);
    });
  });

  // ── LayoutSnapshot 测试 ──
  group('LayoutSnapshot', () {
    test('stores generation and pages count', () {
      final spec = const LayoutSpec(
        viewportWidth: 400,
        viewportHeight: 600,
        contentPadding: 20,
        fontFamily: 'sans-serif',
        fontSize: 16,
        lineHeight: 1.5,
        paragraphSpacing: 8,
      );
      final snapshot = LayoutSnapshot(
        generation: 1,
        key: LayoutKey.fromSpec(spec),
        // ignore: prefer_const_constructors
        chapter: ReaderChapterIr(plainText: '', blocks: []),
        pages: const [
          PagePlan(
            pageIndex: 0,
            startUtf16: 0,
            endUtf16: 0,
            fragments: [],
            isLastPage: true,
          ),
        ],
        isComplete: true,
      );

      expect(snapshot.generation, 1);
      expect(snapshot.totalPages, 1);
      expect(snapshot.isComplete, isTrue);
    });
  });
}
