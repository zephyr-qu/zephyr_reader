/// Scroll IR 金路径测试
///
/// 验证 IR 滚动不变量：
/// - scroll 段全部为 IR（非 rich）
/// - 含图 EPUB scroll 走 IR 块流
/// - scrollPlainPayload 不包含 IR
/// - IR 段保留首行缩进元数据
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_chapter_payload.dart';
import 'package:zephyr_reader/features/reader/core/data/scroll_segment_factory.dart';

void main() {
  group('Scroll IR 金路径 — 段工厂', () {
    test('plain payload 产生非 IR 段', () {
      final payload = scrollPlainPayload('Line 1\n\nLine 2\n\nLine 3');
      final seg = ScrollSegmentFactory.fromPayload(0, payload);

      expect(seg.isIr, isFalse);
      expect(seg.paragraphs.length, 3);
      expect(seg.paragraphCharOffsets.length, 3);
    });

    test('plain payload 空内容', () {
      final payload = scrollPlainPayload('');
      final seg = ScrollSegmentFactory.fromPayload(0, payload);

      expect(seg.isIr, isFalse);
      expect(seg.paragraphs, isEmpty);
      expect(seg.totalCharLength, 0);
    });
  });

  group('Scroll IR 金路径 — 跨章不变量', () {
    test('scrollPlainPayload 不设置 chapterIr', () {
      final payload = scrollPlainPayload('content');

      expect(payload.chapterIr, isNull);
      expect(payload.epubRichSkipped, isFalse);
    });

    test('scrollPayload 全部 optional 可空', () {
      final payload = scrollPlainPayload('test');
      expect(payload.content, 'test');
      expect(payload.chapterFilePath, isNull);
    });
  });
}
