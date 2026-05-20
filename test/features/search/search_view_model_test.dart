library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/search/application/search_view_model.dart';
import 'package:zephyr_reader/features/search/data/search_service.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

import '../../helpers/mock_rust_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SearchViewModel', () {
    late MockRustStorageService storage;
    late SearchRepository repo;
    late SearchViewModel vm;

    setUp(() async {
      storage = MockRustStorageService();
      repo = SearchRepository(storage);
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

      test('search 应返回匹配结果', () async {
        await storage.saveBook(
          Book(
            bookId: 'book_1',
            filePath: '/test.txt',
            fileSize: 1000,
            title: '三国演义',
            author: '罗贯中',
            chapterCount: 10,
            totalCharacters: 50000,
            format: BookFormat.txt,
            addedAt: DateTime(2026, 1, 1),
            status: BookStatus.reading,
            isPinned: false,
          ),
        );
        await storage.saveBook(
          Book(
            bookId: 'book_2',
            filePath: '/test2.txt',
            fileSize: 1000,
            title: '西游记',
            author: '吴承恩',
            chapterCount: 8,
            totalCharacters: 40000,
            format: BookFormat.txt,
            addedAt: DateTime(2026, 1, 1),
            status: BookStatus.reading,
            isPinned: false,
          ),
        );

        vm.updateKeyword('三国');
        await vm.search();

        expect(vm.results.value.value?.length, equals(1));
        expect(vm.results.value.value?.first.title, equals('三国演义'));
        expect(vm.isSearching.value, isFalse);
      });

      test('search 无匹配应返回空列表', () async {
        vm.updateKeyword('不存在的书');
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
