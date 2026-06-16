import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/core/data/page_content_cache.dart';

void main() {
  group('PageContentCache', () {
    late PageContentCache cache;

    setUp(() {
      cache = PageContentCache();
    });

    test('put 后 get 返回缓存内容', () {
      cache.put(0, 'page zero');
      expect(cache.get(0), 'page zero');
    });

    test('不存在的页返回 null', () {
      expect(cache.get(99), isNull);
    });

    test('warm 同 put', () {
      cache.warm(2, 'page two');
      expect(cache.get(2), 'page two');
    });

    test('clear 清空所有缓存', () {
      cache.put(0, 'a');
      cache.put(1, 'b');
      cache.clear();
      expect(cache.length, 0);
      expect(cache.get(0), isNull);
    });

    test('trimAround 保留 center±windowRadius', () {
      for (int i = 0; i < 20; i++) {
        cache.put(i, 'page $i');
      }
      cache.trimAround(10);
      // 10±5 → 5..15 保留
      expect(cache.get(4), isNull);
      expect(cache.get(5), isNotNull);
      expect(cache.get(10), isNotNull);
      expect(cache.get(15), isNotNull);
      expect(cache.get(16), isNull);
    });

    test('trimAround 边界 — center 靠近 0', () {
      for (int i = 0; i < 10; i++) {
        cache.put(i, 'page $i');
      }
      cache.trimAround(2);
      // 2±5 → 0..7, but negative clamped — 0..7
      expect(cache.get(0), isNotNull);
      expect(cache.get(7), isNotNull);
      expect(cache.get(8), isNull);
    });

    test('containsKey 正确反映存在性', () {
      cache.put(5, 'hello');
      expect(cache.containsKey(5), true);
      expect(cache.containsKey(6), false);
    });

    test('removeWhere 条件移除', () {
      cache.put(0, 'keep');
      cache.put(1, 'remove');
      cache.removeWhere((k, v) => k == 1);
      expect(cache.get(0), 'keep');
      expect(cache.get(1), isNull);
    });

    test('length 返回缓存数量', () {
      expect(cache.length, 0);
      cache.put(0, 'a');
      cache.put(1, 'b');
      expect(cache.length, 2);
    });
  });
}
