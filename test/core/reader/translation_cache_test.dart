import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/bilingual/data/bilingual_cache.dart';

void main() {
  group('BilingualCache', () {
    test('stores and retrieves translation', () {
      final cache = BilingualCache(maxEntries: 5);
      cache.put(0, 'Hello world', '你好世界');
      expect(cache.get(0, 'Hello world'), '你好世界');
    });

    test('returns null for unknown chapter', () {
      final cache = BilingualCache(maxEntries: 5);
      cache.put(0, 'Hello', '你好');
      expect(cache.get(1, 'Hello'), isNull);
    });

    test('returns null for different content', () {
      final cache = BilingualCache(maxEntries: 5);
      cache.put(0, 'Hello', '你好');
      expect(cache.get(0, 'World'), isNull);
    });

    test('invalidateChapter removes only specified chapter', () {
      final cache = BilingualCache(maxEntries: 10);
      cache.put(0, 'Chapter 0', '第0章');
      cache.put(1, 'Chapter 1', '第1章');
      cache.put(2, 'Chapter 2', '第2章');

      cache.invalidateChapter(1);

      expect(cache.get(0, 'Chapter 0'), '第0章');
      expect(cache.get(1, 'Chapter 1'), isNull);
      expect(cache.get(2, 'Chapter 2'), '第2章');
    });

    test('clear removes all entries', () {
      final cache = BilingualCache(maxEntries: 10);
      cache.put(0, 'Hello', '你好');
      cache.put(1, 'World', '世界');

      cache.clear();

      expect(cache.get(0, 'Hello'), isNull);
      expect(cache.get(1, 'World'), isNull);
    });

    test('evicts one entry when over max capacity', () {
      final cache = BilingualCache(maxEntries: 2);

      cache.put(0, 'A', 'A-translated');
      cache.put(1, 'B', 'B-translated');

      expect(cache.get(0, 'A'), 'A-translated');
      expect(cache.get(1, 'B'), 'B-translated');

      // Adding third should evict one entry (only 2 remain)
      cache.put(2, 'C', 'C-translated');

      // At least one of A or B was evicted
      final aExists = cache.get(0, 'A') != null;
      final bExists = cache.get(1, 'B') != null;
      expect(
        aExists && bExists,
        false,
        reason: 'One entry should have been evicted',
      );
      expect(cache.get(2, 'C'), 'C-translated');
    });

    test('different chapter indices are isolated', () {
      final cache = BilingualCache(maxEntries: 10);
      cache.put(0, 'Same content', 'translated-0');
      cache.put(1, 'Same content', 'translated-1');

      expect(cache.get(0, 'Same content'), 'translated-0');
      expect(cache.get(1, 'Same content'), 'translated-1');
    });

    test('sha256 produces deterministic hash', () {
      final h1 = BilingualCache.sha256('Hello World');
      final h2 = BilingualCache.sha256('Hello World');
      expect(h1, h2);
    });

    test('sha256 differs for different content', () {
      final h1 = BilingualCache.sha256('Hello');
      final h2 = BilingualCache.sha256('World');
      expect(h1, isNot(h2));
    });
  });
}
