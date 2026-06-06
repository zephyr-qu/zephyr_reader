// test/features/search/search_history_service_test.dart
//
// SearchHistoryService 单元测试 — 纯 Dart 逻辑，无依赖

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/search/application/services/search_history_service.dart';

void main() {
  group('SearchHistoryService', () {
    late SearchHistoryService service;

    setUp(() {
      service = SearchHistoryService();
    });

    test('初始状态为空列表', () {
      expect(service.getHistory(), isEmpty);
    });

    test('addHistory 添加单条记录', () {
      service.addHistory('flutter');
      expect(service.getHistory(), ['flutter']);
    });

    test('addHistory 新记录插入最前', () {
      service.addHistory('a');
      service.addHistory('b');
      expect(service.getHistory(), ['b', 'a']);
    });

    test('addHistory 忽略空字符串', () {
      service.addHistory('   ');
      service.addHistory('');
      expect(service.getHistory(), isEmpty);
    });

    test('addHistory 已有记录移到最前，不重复', () {
      service.addHistory('a');
      service.addHistory('b');
      service.addHistory('a');
      expect(service.getHistory(), ['a', 'b']);
    });

    test('addHistory 超出 maxHistory 自动裁剪', () {
      for (int i = 0; i < 25; i++) {
        service.addHistory('q$i');
      }
      final history = service.getHistory();
      expect(history.length, 20);
      expect(history.first, 'q24');
      expect(history.last, 'q5');
    });

    test('removeHistory 移除指定记录', () {
      service.addHistory('a');
      service.addHistory('b');
      service.addHistory('c');
      service.removeHistory('b');
      expect(service.getHistory(), ['c', 'a']);
    });

    test('removeHistory 不存在的记录不影响列表', () {
      service.addHistory('a');
      service.removeHistory('nonexistent');
      expect(service.getHistory(), ['a']);
    });

    test('clearHistory 清空所有记录', () {
      service.addHistory('a');
      service.addHistory('b');
      service.clearHistory();
      expect(service.getHistory(), isEmpty);
    });

    test('getHistory 返回不可变副本', () {
      service.addHistory('a');
      final history = service.getHistory();
      expect(() => history.add('b'), throwsUnsupportedError);
      // 原始数据不受影响
      expect(service.getHistory(), ['a']);
    });
  });
}
