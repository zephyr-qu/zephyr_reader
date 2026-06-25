/// Scroll IR 金路径测试
///
/// 验证 P4-1 收敛后的不变量：
/// - scroll 段全部为 IR（非 rich）
/// - 含图 EPUB scroll 走 IR 块流
/// - 跨章 forward 不产生 epubRichSkipped
/// - scroll ↔ pagination 切换保留段首缩进（ADR-010）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_chapter_payload.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_segment_factory.dart';
import 'package:zephyr_reader/src/rust/domain/types/content_ir.dart';

/// 构造模拟 IR 块。
List<ContentBlock> _makeIrBlocks({
  int paragraphCount = 3,
  bool includeImage = false,
}) {
  final blocks = <ContentBlock>[];
  var plainStart = 0;
  for (var i = 0; i < paragraphCount; i++) {
    final text = 'Paragraph $i content.\n';
    blocks.add(ContentBlock.text(TextBlock(
      plain: BlockPlainRange(plainStart: plainStart, plainLen: text.length),
      text: text,
      style: TextBlockStyle(
        isHeading: false,
        headingLevel: 0,
        textIndentEm: i == 0 ? 2.0 : null,
        marginBottomEm: 1.0,
      ),
      spans: const [],
    )));
    plainStart += text.length;
  }
  if (includeImage) {
    blocks.add(ContentBlock.image(ImageBlock(
      plain: BlockPlainRange(plainStart: plainStart, plainLen: 1),
      assetId: 'img_cover',
    )));
  }
  return blocks;
}

ChapterContentIr _makeChapterIr({
  int paragraphCount = 3,
  bool includeImage = false,
}) {
  final blocks = _makeIrBlocks(
    paragraphCount: paragraphCount,
    includeImage: includeImage,
  );
  final plainText = blocks
      .map((b) => b.when(
            text: (tb) => tb.text,
            image: (_) => '\uFFFC',
          ))
      .join();
  return ChapterContentIr(blocks: blocks, plainText: plainText);
}

void main() {
  group('Scroll IR 金路径 — 段工厂', () {
    test('纯文 IR payload 产生 isIr 段', () {
      final ir = _makeChapterIr(paragraphCount: 3);
      final payload = scrollIrPayload(
        chapterIr: ir,
        chapterFilePath: '/test.epub',
      );
      final seg = ScrollSegmentFactory.fromPayload(0, payload);

      expect(seg.isIr, isTrue);
      expect(seg.isRich, isFalse);
      expect(seg.irBlocks, isNotEmpty);
      expect(seg.paragraphCount, 3);
      expect(seg.totalCharLength, greaterThan(0));
    });

    test('含图 IR payload 产生 isIr 段且含图片 block', () {
      final ir = _makeChapterIr(paragraphCount: 2, includeImage: true);
      final payload = scrollIrPayload(
        chapterIr: ir,
        chapterFilePath: '/test.epub',
      );
      final seg = ScrollSegmentFactory.fromPayload(0, payload);

      expect(seg.isIr, isTrue);
      expect(seg.irBlocks!.any((b) => b.when(
            text: (_) => false,
            image: (_) => true,
          )), isTrue);
    });

    test('plain payload 产生非 IR 非 rich 段', () {
      final payload = scrollPlainPayload('Line 1\n\nLine 2\n\nLine 3');
      final seg = ScrollSegmentFactory.fromPayload(0, payload);

      expect(seg.isIr, isFalse);
      expect(seg.isRich, isFalse);
      expect(seg.paragraphs.length, 3);
      expect(seg.paragraphCharOffsets.length, 3);
    });
  });

  group('Scroll IR 金路径 — 跨章不变量', () {
    test('scrollIrPayload 不设置 richParagraphs/richRootSpan', () {
      final ir = _makeChapterIr();
      final payload = scrollIrPayload(
        chapterIr: ir,
        chapterFilePath: '/test.epub',
      );

      expect(payload.richParagraphs, isNull);
      expect(payload.richRootSpan, isNull);
      expect(payload.epubRichSkipped, isFalse);
    });

    test('scrollPlainPayload 不设置 richParagraphs/richRootSpan', () {
      final payload = scrollPlainPayload('content');

      expect(payload.richParagraphs, isNull);
      expect(payload.richRootSpan, isNull);
    });
  });

  group('Scroll IR 金路径 — ADR-010 段首缩进保留', () {
    test('IR 段保留 textIndentEm 元数据', () {
      final ir = _makeChapterIr(paragraphCount: 2);
      final payload = scrollIrPayload(
        chapterIr: ir,
        chapterFilePath: '/test.epub',
      );
      final seg = ScrollSegmentFactory.fromPayload(0, payload);

      // 首段应保留 2em 缩进
      final firstBlock = seg.irBlocks!.first.when(
        text: (tb) => tb,
        image: (_) => null,
      );
      expect(firstBlock, isNotNull);
      expect(firstBlock!.style.textIndentEm, closeTo(2.0, 0.01));

      // 第二段无缩进
      final secondBlock = seg.irBlocks!.skip(1).first.when(
        text: (tb) => tb,
        image: (_) => null,
      );
      expect(secondBlock, isNotNull);
      expect(secondBlock!.style.textIndentEm, isNull);
    });
  });
}
