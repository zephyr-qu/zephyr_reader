import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/data/line_break_extractor.dart';
import 'package:zephyr_reader/features/reader/spike/flutter_block_paginator.dart';
import 'package:zephyr_reader/src/rust/domain/types/block_pagination.dart';
import 'package:zephyr_reader/src/rust/domain/types/content_ir.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test('imageDisplayHeightDp uses intrinsic scale without upscaling', () {
    expect(
      imageDisplayHeightDp(
        contentWidthDp: 200,
        intrinsicWidth: 400,
        intrinsicHeight: 200,
      ),
      closeTo(100, 0.01),
    );
    expect(
      imageDisplayHeightDp(
        contentWidthDp: 400,
        intrinsicWidth: 200,
        intrinsicHeight: 100,
      ),
      closeTo(100, 0.01), // scale capped at 1.0
    );
    expect(
      imageDisplayHeightDp(contentWidthDp: 200),
      closeTo(200 * kDefaultImageHeightRatio, 0.01),
    );
  });

  test('small image inline-contains with preceding text', () {
    const text = '前文';
    final ir = ChapterContentIr(
      blocks: [
        ContentBlock.text(
          TextBlock(
            plain: const BlockPlainRange(plainStart: 0, plainLen: 2),
            text: text,
            style: const TextBlockStyle(isHeading: false, headingLevel: 0),
            spans: const [],
          ),
        ),
        ContentBlock.image(
          const ImageBlock(
            plain: BlockPlainRange(plainStart: 2, plainLen: 1),
            assetId: 'img1',
            intrinsicWidth: 100,
            intrinsicHeight: 40,
          ),
        ),
      ],
      plainText: '$text\uFFFC',
    );

    final pages = FlutterBlockPaginator.paginate(
      ir,
      config: config,
      contentWidthDp: 300,
      contentHeightDp: 400,
    );

    expect(pages, hasLength(1));
    final img = pages.single.slices.where((s) => s.isImage).single;
    expect(img.imageLayout, ImageBlockLayout.inlineContain);
    expect(img.assetId, 'img1');
    expect(pages.single.endOffset, 3);
  });

  test('tall image gets full-page after flushing text', () {
    const text = '前文一段';
    const after = '后文';
    final ir = ChapterContentIr(
      blocks: [
        ContentBlock.text(
          TextBlock(
            plain: BlockPlainRange(plainStart: 0, plainLen: text.length),
            text: text,
            style: const TextBlockStyle(isHeading: false, headingLevel: 0),
            spans: const [],
          ),
        ),
        ContentBlock.image(
          ImageBlock(
            plain: BlockPlainRange(plainStart: text.length, plainLen: 1),
            assetId: 'tall',
            intrinsicWidth: 200,
            intrinsicHeight: 800,
          ),
        ),
        ContentBlock.text(
          TextBlock(
            plain: BlockPlainRange(
              plainStart: text.length + 1,
              plainLen: after.length,
            ),
            text: after,
            style: const TextBlockStyle(isHeading: false, headingLevel: 0),
            spans: const [],
          ),
        ),
      ],
      plainText: '$text\uFFFC$after',
    );

    final pages = FlutterBlockPaginator.paginate(
      ir,
      config: config,
      contentWidthDp: 200,
      contentHeightDp: 300,
    );

    expect(pages.length, greaterThanOrEqualTo(2));
    final imgPage = pages.firstWhere((p) => p.slices.any((s) => s.isImage));
    expect(imgPage.slices, hasLength(1));
    expect(imgPage.slices.single.imageLayout, ImageBlockLayout.fullPage);
    expect(imgPage.slices.single.assetId, 'tall');
    expect(imgPage.slices.any((s) => !s.isImage), isFalse);
    expect(pages.last.endOffset, ir.plainText.length);
  });

  test('inline image packing includes vertical padding in budget', () {
    // 前文吃掉大部分页高，剩余仅够「裸图高」不够「图+8dp padding」→ 应独占页。
    const text = '前文';
    final ir = ChapterContentIr(
      blocks: [
        ContentBlock.text(
          TextBlock(
            plain: const BlockPlainRange(plainStart: 0, plainLen: 2),
            text: text,
            style: const TextBlockStyle(isHeading: false, headingLevel: 0),
            spans: const [],
          ),
        ),
        ContentBlock.image(
          const ImageBlock(
            plain: BlockPlainRange(plainStart: 2, plainLen: 1),
            assetId: 'pad',
            intrinsicWidth: 200,
            intrinsicHeight: 40, // displayH @200w = 40
          ),
        ),
      ],
      plainText: '$text\uFFFC',
    );

    final pages = FlutterBlockPaginator.paginate(
      ir,
      config: config,
      contentWidthDp: 200,
      contentHeightDp: 70, // packBudget=68；文约 24+8，剩 ~36；图裸 40+8=48 > 36
    );

    final imgPage = pages.firstWhere((p) => p.slices.any((s) => s.isImage));
    expect(imgPage.slices.single.imageLayout, ImageBlockLayout.fullPage);
  });
}
