// test/features/search/search_history_service_test.dart
//
// SearchHistoryService — 纯内存搜索历史服务，无任何外部依赖
//
// 覆盖：初始空状态、添加/去重/上限、清除、单条移除

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/search/application/services/search_history_service.dart';

void main() {
  group('SearchHistoryService', () {
    late SearchHistoryService service;

    setUp(() {
      service = SearchHistoryService();
    });

    test('starts with empty history', () {
      expect(service.getHistory(), isEmpty);
    });

    group('addHistory', () {
      test('adds a query to history', () {
        service.addHistory('flutter');
        expect(service.getHistory(), ['flutter']);
      });

      test('ignores empty string', () {
        service.addHistory('');
        expect(service.getHistory(), isEmpty);
      });

      test('ignores whitespace-only string', () {
        service.addHistory('   ');
        expect(service.getHistory(), isEmpty);
      });

      test('prepends new queries to front', () {
        service.addHistory('alpha');
        service.addHistory('beta');
        expect(service.getHistory(), ['beta', 'alpha']);
      });

      test('moves duplicate to front without duplication', () {
        service.addHistory('a');
        service.addHistory('b');
        service.addHistory('a');
        expect(service.getHistory(), ['a', 'b']);
      });

      test('caps at maxHistory entries', () {
        for (var i = 0; i < 25; i++) {
          service.addHistory('query_$i');
        }
        final history = service.getHistory();
        expect(history.length, 20);
        // newest entry should be first
        expect(history.first, 'query_24');
        // oldest entry (query_5) should have been dropped
        expect(history, isNot(contains('query_4')));
      });
    });

    group('removeHistory', () {
      test('removes a specific query', () {
        service.addHistory('a');
        service.addHistory('b');
        service.addHistory('c');
        service.removeHistory('b');
        expect(service.getHistory(), ['c', 'a']);
      });

      test('does nothing when query not found', () {
        service.addHistory('a');
        service.removeHistory('nonexistent');
        expect(service.getHistory(), ['a']);
      });
    });

    group('clearHistory', () {
      test('clears all history', () {
        service.addHistory('a');
        service.addHistory('b');
        service.clearHistory();
        expect(service.getHistory(), isEmpty);
      });

      test('clear on empty history does not throw', () {
        expect(() => service.clearHistory(), returnsNormally);
      });
    });
  });
}
