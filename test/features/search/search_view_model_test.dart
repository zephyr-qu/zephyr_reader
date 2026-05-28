library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/search/application/search_view_model.dart';
import 'package:zephyr_reader/features/search/data/search_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SearchViewModel', () {
    late SearchRepository repo;
    late SearchViewModel vm;

    setUp(() async {
      repo = SearchRepository();
      vm = SearchViewModel(repo);
    });

    group('搜索功能', () {
      test('初始状态应有空结果', () {
        expect(vm.keyword.value, isEmpty);
        expect(vm.results.value.value, isEmpty);
        expect(vm.isSearching.value, isFalse);
        expect(vm.hasMore.value, isFalse);
        expect(vm.currentPage.value, equals(1));
      });

      test('空关键词应返回空结果', () async {
        await vm.search();
        expect(vm.results.value.value, isEmpty);
      });

      test('search 应切换 isSearching 状态', () async {
        vm.updateKeyword('三国');

        final future = vm.search();
        expect(vm.isSearching.value, isTrue);
        await future;
        expect(vm.isSearching.value, isFalse);
      });
    });

    group('搜索结果导航', () {
      test('clear 应清空搜索结果', () {
        vm.updateKeyword('测试');
        vm.clear();

        expect(vm.keyword.value, isEmpty);
        expect(vm.results.value.value, isEmpty);
        expect(vm.currentPage.value, equals(1));
      });

      test('updateKeyword 应更新关键词', () {
        vm.updateKeyword('新关键词');
        expect(vm.keyword.value, equals('新关键词'));
      });
    });
  });
}
