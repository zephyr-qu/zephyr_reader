import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_chapter_segment.dart';
import 'package:zephyr_reader/features/reader/core/application/scroll_document_composer.dart';
import 'package:zephyr_reader/src/rust/domain/types/rich_text.dart';

ScrollChapterSegment makeSeg(int chapter, int pageIdx) {
  final paragraphs = <String>[];
  final offsets = <int>[];
  var acc = 0;
  for (var i = 0; i < 5; i++) {
    paragraphs.add('Chapter$chapter Page$pageIdx para$i');
    offsets.add(acc);
    acc += paragraphs.last.length + 2;
  }
  return ScrollChapterSegment(
    chapterIndex: chapter,
    paragraphs: paragraphs,
    paragraphCharOffsets: offsets,
  );
}

void main() {
  group('ScrollDocumentComposer', () {
    test('初始化含中心段', () {
      final seg = makeSeg(0, 0);
      final c = ScrollDocumentComposer(centerChapterIndex: 0);
      c.reset(seg);
      expect(c.segments.length, 1);
      expect(c.centerChapterIndex, 0);
      expect(c.totalParagraphCount, 5);
    });

    test('appendNext 追加下一章', () {
      final c0 = makeSeg(0, 0);
      final c1 = makeSeg(1, 0);
      final c = ScrollDocumentComposer(centerChapterIndex: 0);
      c.reset(c0);
      expect(c.appendNext(c1), isTrue);
      expect(c.segments.length, 2);
      expect(c.totalParagraphCount, 10);
    });

    test('appendNext 拒绝无序追加', () {
      final c0 = makeSeg(1, 0);
      final c1 = makeSeg(0, 0);
      final c = ScrollDocumentComposer(centerChapterIndex: 1);
      c.reset(c0);
      expect(c.appendNext(c1), isFalse);
      expect(c.segments.length, 1);
    });

    test('prependPrev 插入上一章', () {
      final c1 = makeSeg(1, 0);
      final c0 = makeSeg(0, 0);
      final c = ScrollDocumentComposer(centerChapterIndex: 1);
      c.reset(c1);
      expect(c.prependPrev(c0), isTrue);
      expect(c.segments.length, 2);
      expect(c.segments.first.chapterIndex, 0);
    });

    test('prependPrev 拒绝无序插入', () {
      final c0 = makeSeg(0, 0);
      final c1 = makeSeg(1, 0);
      final c = ScrollDocumentComposer(centerChapterIndex: 0);
      c.reset(c0);
      expect(c.prependPrev(c1), isFalse);
      expect(c.segments.length, 1);
    });

    test('reset 清空窗口并设新中心', () {
      final c0 = makeSeg(0, 0);
      final c1 = makeSeg(1, 0);
      final c2 = makeSeg(2, 0);
      final c = ScrollDocumentComposer(centerChapterIndex: 1);
      c.reset(c1);
      c.appendNext(c2);
      expect(c.segments.length, 2);
      c.reset(c0);
      expect(c.segments.length, 1);
      expect(c.centerChapterIndex, 0);
    });

    test('resolveGlobalIndex 正确映射', () {
      final c0 = makeSeg(0, 0);
      final c1 = makeSeg(1, 0);
      final c = ScrollDocumentComposer(centerChapterIndex: 0);
      c.reset(c0);
      c.appendNext(c1);
      final r0 = c.resolveGlobalIndex(0)!;
      expect(r0.segIdx, 0);
      expect(r0.localIdx, 0);
      final r5 = c.resolveGlobalIndex(5)!;
      expect(r5.segIdx, 1);
      expect(r5.localIdx, 0);
      expect(c.resolveGlobalIndex(99), isNull);
    });

    test('trim 保持窗口最多 3 段', () {
      final segs = [makeSeg(0, 0), makeSeg(1, 0), makeSeg(2, 0), makeSeg(3, 0)];
      final c = ScrollDocumentComposer(centerChapterIndex: 2);
      c.reset(segs[2]);
      c.appendNext(segs[3]);
      c.prependPrev(segs[1]);
      c.prependPrev(segs[0]);
      expect(c.segments.length, 3); // dropped segs[0]
      expect(c.segments.first.chapterIndex, 1);
      expect(c.segments.last.chapterIndex, 3);
    });

    test('updateCenterChapter 后 trim 正确', () {
      final c = ScrollDocumentComposer(centerChapterIndex: 0);
      c.reset(makeSeg(0, 0));
      expect(c.segments.length, 1, reason: 'after reset');
      c.appendNext(makeSeg(1, 0));
      expect(c.segments.length, 2, reason: 'after appendNext seg1');
      c.updateCenterChapter(1);
      expect(c.segments.length, 2, reason: 'after updateCenter to 1');
      c.updateCenterChapter(0);
      expect(c.segments.length, 2, reason: 'after updateCenter back to 0');
    });

    test('charOffsetAtOffset 映射 scrollOffset → (chapterIndex, charOffset)', () {
      final c0 = makeSeg(0, 0);
      final c = ScrollDocumentComposer(centerChapterIndex: 0);
      c.reset(c0);
      // 每个段落高度 100px，total 5 段 = 500px
      final result = c.charOffsetAtOffset(50, (_) => 100);
      // 50px → 第 0 段 50% 位置 → charOffset 在第 0 段内
      expect(result.chapterIndex, 0);
      expect(result.charOffset, greaterThan(0));
    });

    test('charOffsetAtOffset 返回最后段落结尾当 offset 超出范围', () {
      final c0 = makeSeg(0, 0);
      final c = ScrollDocumentComposer(centerChapterIndex: 0);
      c.reset(c0);
      final result = c.charOffsetAtOffset(99999, (_) => 100);
      expect(result.chapterIndex, 0);
      expect(result.charOffset, c0.totalCharLength);
    });

    test('hasChapter 检查章节是否存在', () {
      final c0 = makeSeg(0, 0);
      final c1 = makeSeg(1, 0);
      final c = ScrollDocumentComposer(centerChapterIndex: 0);
      c.reset(c0);
      c.appendNext(c1);
      expect(c.hasChapter(0), isTrue);
      expect(c.hasChapter(1), isTrue);
      expect(c.hasChapter(2), isFalse);
    });

    test('charOffsetAtOffset 含图片 rich 段不越界', () {
      final paragraphs = List.generate(10, (i) => 'para$i');
      final offsets = List.generate(10, (i) => i * 8);
      final rich = <RichParagraph>[
        for (var i = 0; i < 10; i++)
          RichParagraph(
            spans: const [],
            indent: 0,
            isHeading: false,
            headingLevel: 0,
            isImage: false,
            imageData: Uint8List(0),
          ),
        RichParagraph(
          spans: const [],
          indent: 0,
          isHeading: false,
          headingLevel: 0,
          isImage: true,
          imageData: Uint8List.fromList([1, 2, 3]),
        ),
      ];
      final seg = ScrollChapterSegment(
        chapterIndex: 0,
        paragraphs: paragraphs,
        paragraphCharOffsets: offsets,
        richParagraphs: rich,
      );
      expect(seg.paragraphCount, 11);
      expect(seg.paragraphs.length, 10);

      final c = ScrollDocumentComposer(centerChapterIndex: 0);
      c.reset(seg);
      expect(
        () => c.charOffsetAtOffset(1050, (_) => 100),
        returnsNormally,
      );
      final result = c.charOffsetAtOffset(1050, (_) => 100);
      expect(result.chapterIndex, 0);
    });
  });
}
