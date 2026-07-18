import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zephyr_reader/core/reader_engine/layout/block_layout.dart';
import 'package:zephyr_reader/core/reader_engine/layout/layout_spec.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/page_packer.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/page_plan.dart'
    show PagePlanValidator, ReaderIrBlockLayout;
import 'package:zephyr_reader/src/rust/pipeline/types.dart';

LayoutSpec _spec({
  double fontSize = 16,
  double lineHeight = 1.5,
  double paragraphSpacing = 0,
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
  paragraphSpacing: paragraphSpacing,
);

/// 创建模拟文本 BlockLayout。
BlockLayout _textBlock(
  int idx,
  String text, {
  EdgeInsets margins = EdgeInsets.zero,
}) {
  // Estimate line height as fontSize * lineHeight * textScaler with 8dp slack
  const fontSize = 16.0;
  const lineH = fontSize * 1.5;
  return BlockLayout(
    blockIndex: idx,
    startUtf16: 0,
    endUtf16: text.length,
    margins: margins,
    style: const BlockStyle(isHeading: false, headingLevel: 0),
    lines: [
      LineLayout(
        startUtf16: 0,
        endUtf16: text.length,
        height: lineH,
        baseline: lineH * 0.8,
      ),
    ],
  );
}

/// 创建模拟图片 BlockLayout。
BlockLayout _imageBlock(int idx, {int start = 0, int end = 1}) => BlockLayout(
  blockIndex: idx,
  startUtf16: start,
  endUtf16: end,
  lines: const [],
  isImage: true,
  assetId: 'img_$idx',
);

void main() {
  group('PagePacker pack text blocks', () {
    test('single block fits one page', () {
      final packer = PagePacker(spec: _spec(), maxHeight: 800);
      final block = _textBlock(0, 'Hello world');
      packer.appendTextBlock(
        block: block,
        blockText: 'Hello world',
        blockRuns: const [],
        blockPlainStart: 0,
        blockStyle: const BlockStyle(isHeading: false, headingLevel: 0),
      );
      final pages = packer.finish();

      expect(pages, hasLength(1));
      expect(pages.single.startUtf16, 0);
      expect(pages.single.endUtf16, 'Hello world'.length);
      expect(pages.single.fragments.single.text, 'Hello world');
      expect(pages.single.isLastPage, isTrue);
    });

    test('fragment text preserves source without duplicated first line', () {
      final packer = PagePacker(spec: _spec(), maxHeight: 800);
      const text = 'firstsecond';
      const block = BlockLayout(
        blockIndex: 0,
        startUtf16: 0,
        endUtf16: 11,
        lines: [
          LineLayout(startUtf16: 0, endUtf16: 5, height: 24, baseline: 19),
          LineLayout(startUtf16: 5, endUtf16: 11, height: 24, baseline: 19),
        ],
      );
      packer.appendTextBlock(
        block: block,
        blockText: text,
        blockRuns: const [],
        blockPlainStart: 0,
        blockStyle: const BlockStyle(isHeading: false, headingLevel: 0),
      );

      final fragment = packer.finish().single.fragments.single;
      expect(fragment.text, text);
      expect(fragment.endUtf16 - fragment.startUtf16, text.length);
    });

    test('chunk continuation preserves one semantic block boundary', () {
      final packer = PagePacker(
        spec: _spec(paragraphSpacing: 12),
        maxHeight: 800,
      );
      const style = BlockStyle(isHeading: false, headingLevel: 0);
      packer.appendTextBlock(
        block: _textBlock(0, 'first'),
        blockText: 'first',
        blockRuns: const [],
        blockPlainStart: 0,
        blockStyle: style,
        endsBlock: false,
      );
      packer.appendTextBlock(
        block: _textBlock(0, 'second'),
        blockText: 'second',
        blockRuns: const [],
        blockPlainStart: 5,
        blockStyle: style,
        startsBlock: false,
      );

      final fragments = packer.finish().single.fragments;
      expect(fragments.map((f) => f.text).join(), 'firstsecond');
      expect(fragments.map((f) => f.isBlockStart), [true, false]);
      expect(fragments.map((f) => f.isBlockEnd), [false, true]);
    });

    test('progress snapshot includes pending fragment without mutation', () {
      final packer = PagePacker(spec: _spec(), maxHeight: 800);
      packer.appendTextBlock(
        block: _textBlock(0, 'pending'),
        blockText: 'pending',
        blockRuns: const [],
        blockPlainStart: 0,
        blockStyle: const BlockStyle(isHeading: false, headingLevel: 0),
      );

      final snapshot = packer.snapshotPages(isPartial: true);
      expect(snapshot.single.fragments.single.text, 'pending');
      expect(snapshot.single.isLastPage, isFalse);
      expect(packer.finish().single.fragments.single.text, 'pending');
    });

    test('multiple blocks pack into one page', () {
      final packer = PagePacker(
        spec: _spec(viewportHeight: 800),
        maxHeight: 800,
      );

      for (var i = 0; i < 3; i++) {
        final text = 'Block $i text';
        final block = _textBlock(i, text);
        packer.appendTextBlock(
          block: block,
          blockText: text,
          blockRuns: const [],
          blockPlainStart: i * 100,
          blockStyle: const BlockStyle(isHeading: false, headingLevel: 0),
        );
      }
      final pages = packer.finish();

      expect(pages, hasLength(1));
      expect(pages.single.fragments, hasLength(3));
    });

    test('many blocks overflow to second page', () {
      final packer = PagePacker(
        spec: _spec(viewportHeight: 100),
        maxHeight: 100,
      );

      for (var i = 0; i < 10; i++) {
        final text = 'B$i';
        final block = _textBlock(i, text);
        packer.appendTextBlock(
          block: block,
          blockText: text,
          blockRuns: const [],
          blockPlainStart: i * 3,
          blockStyle: const BlockStyle(isHeading: false, headingLevel: 0),
        );
      }
      final pages = packer.finish();

      expect(pages.length, greaterThan(1));
    });

    test('pages are continuous with no gaps', () {
      final packer = PagePacker(
        spec: _spec(viewportHeight: 100),
        maxHeight: 100,
      );
      var offset = 0;
      for (var i = 0; i < 10; i++) {
        final text = 'Block_$i\n';
        final block = _textBlock(i, text);
        packer.appendTextBlock(
          block: block,
          blockText: text,
          blockRuns: const [],
          blockPlainStart: offset,
          blockStyle: const BlockStyle(isHeading: false, headingLevel: 0),
        );
        offset += text.length;
      }
      final pages = packer.finish();

      expect(PagePlanValidator.validateContinuity(pages), isNull);
      expect(PagePlanValidator.validateRanges(pages), isNull);
    });
  });

  group('PagePacker image blocks', () {
    test('inline image on first page when space sufficient', () {
      final packer = PagePacker(
        spec: _spec(viewportHeight: 800),
        maxHeight: 800,
      );
      packer.appendImageBlock(
        block: _imageBlock(0),
        blockPlainStart: 0,
        displayHeight: 100,
        assetId: 'img0',
      );
      final pages = packer.finish();

      expect(pages, hasLength(1));
      expect(pages.single.fragments.single.isImage, isTrue);
      expect(pages.single.fragments.single.imageDisplayWidth, 360);
      expect(pages.single.fragments.single.imageDisplayHeight, 100);
    });

    test('inline image follows pending text and keeps measured size', () {
      final packer = PagePacker(spec: _spec(), maxHeight: 800);
      packer.appendTextBlock(
        block: _textBlock(0, 'A'),
        blockText: 'A',
        blockRuns: const [],
        blockPlainStart: 0,
        blockStyle: const BlockStyle(isHeading: false, headingLevel: 0),
      );
      packer.appendImageBlock(
        block: _imageBlock(1, start: 1, end: 2),
        blockPlainStart: 1,
        displayHeight: 100,
        assetId: 'img1',
        intrinsicWidth: 100,
        intrinsicHeight: 100,
      );

      final fragments = packer.finish().single.fragments;
      expect(fragments.map((f) => f.isImage), [false, true]);
      expect(fragments.last.imageDisplayWidth, 100);
      expect(fragments.last.imageDisplayHeight, 100);
    });

    test('oversized image pushes to full-page', () {
      final packer = PagePacker(
        spec: _spec(viewportHeight: 200),
        maxHeight: 200,
      );
      // First small item to fill page start
      packer.appendTextBlock(
        block: _textBlock(0, 'A'),
        blockText: 'A',
        blockRuns: const [],
        blockPlainStart: 0,
        blockStyle: const BlockStyle(isHeading: false, headingLevel: 0),
      );
      packer.appendImageBlock(
        block: _imageBlock(1, start: 1, end: 2),
        blockPlainStart: 1,
        displayHeight: 300,
        assetId: 'img1',
      );
      final pages = packer.finish();

      expect(pages, hasLength(2));
      expect(
        pages.last.fragments.single.imageLayout,
        ReaderIrBlockLayout.fullPage,
      );
      expect(pages.last.usedHeight, packer.packBudget);
    });
  });

  group('PagePacker finish and partial', () {
    test('finish returns all pages in order', () {
      final packer = PagePacker(spec: _spec(viewportHeight: 80), maxHeight: 80);
      for (var i = 0; i < 5; i++) {
        final text = 'X$i';
        final block = _textBlock(i, text);
        packer.appendTextBlock(
          block: block,
          blockText: text,
          blockRuns: const [],
          blockPlainStart: i * 2,
          blockStyle: const BlockStyle(isHeading: false, headingLevel: 0),
        );
      }
      final pages = packer.finish(isPartial: true);

      expect(pages, isNotEmpty);
      expect(
        pages.last.isLastPage,
        isFalse,
        reason: 'partial → last page not final',
      );
    });

    test('empty packer produces one empty page', () {
      final packer = PagePacker(spec: _spec(), maxHeight: 800);
      final pages = packer.finish();
      expect(pages, hasLength(1));
      expect(pages.single.fragments, isEmpty);
    });
  });

  test('split block applies top margin to start and bottom margin to end', () {
    final packer = PagePacker(spec: _spec(), maxHeight: 65);
    const text = 'firstsecond';
    const block = BlockLayout(
      blockIndex: 0,
      startUtf16: 0,
      endUtf16: 11,
      margins: EdgeInsets.only(top: 5, bottom: 7),
      lines: [
        LineLayout(startUtf16: 0, endUtf16: 5, height: 30, baseline: 24),
        LineLayout(startUtf16: 5, endUtf16: 11, height: 30, baseline: 24),
      ],
    );
    packer.appendTextBlock(
      block: block,
      blockText: text,
      blockRuns: const [],
      blockPlainStart: 0,
      blockStyle: const BlockStyle(isHeading: false, headingLevel: 0),
    );

    final pages = packer.finish();
    expect(pages, hasLength(2));
    expect(pages.first.usedHeight, 35);
    expect(pages.last.usedHeight, 37);
    expect(pages.first.fragments.single.isBlockStart, isTrue);
    expect(pages.first.fragments.single.isBlockEnd, isFalse);
    expect(pages.last.fragments.single.isBlockStart, isFalse);
    expect(pages.last.fragments.single.isBlockEnd, isTrue);
  });

  group('PagePacker image display height', () {
    test('uses intrinsic ratio when available', () {
      final h = PagePacker.imageDisplayHeight(
        contentWidthDp: 200,
        intrinsicWidth: 400,
        intrinsicHeight: 600,
      );
      // scale = 200/400 = 0.5, height = 600 * 0.5 = 300
      expect(h, closeTo(300, 0.01));
    });

    test('falls back to default ratio', () {
      final h = PagePacker.imageDisplayHeight(contentWidthDp: 200);
      // 200 * 0.55 = 110
      expect(h, closeTo(110, 0.01));
    });
  });
}
