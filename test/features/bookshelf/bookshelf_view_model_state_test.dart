import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr_reader/features/bookshelf/application/bookshelf_view_model.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookshelfViewModel state machine', () {
    late BookshelfViewModel vm;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      vm = BookshelfViewModel(prefs);
    });

    // ── 初始状态 ──

    test('initial state is correct', () {
      expect(vm.isListView.value, isFalse);
      expect(vm.isSearching.value, isFalse);
      expect(vm.searchKeyword.value, isEmpty);
      expect(vm.selectedCategory.value, isNull);
      expect(vm.selectedStatus.value, isNull);
      expect(vm.defaultSortType.value, BookshelfSortType.lastRead);
    });

    // ── 搜索状态机 ──

    test('startSearch sets isSearching', () {
      vm.startSearch();
      expect(vm.isSearching.value, isTrue);
    });

    test('stopSearch clears keyword and isSearching', () {
      vm.updateSearchKeyword('百年孤独');
      vm.startSearch();
      expect(vm.isSearching.value, isTrue);
      expect(vm.searchKeyword.value, '百年孤独');

      vm.stopSearch();
      expect(vm.isSearching.value, isFalse);
      expect(vm.searchKeyword.value, isEmpty);
    });

    // ── 筛选状态 ──

    test('selectCategory clears search state', () {
      vm.startSearch();
      vm.updateSearchKeyword('test');

      const cat = Category(
        id: 'cat1',
        name: '科幻',
        color: '#FF5722',
        sortOrder: 0,
        isSystem: false,
      );
      vm.selectCategory(cat);

      expect(vm.selectedCategory.value, equals(cat));
      expect(vm.isSearching.value, isFalse);
      expect(vm.searchKeyword.value, isEmpty);
    });

    test('selectStatus resets isSearching', () {
      vm.startSearch();
      vm.selectStatus(BookStatus.reading);
      expect(vm.selectedStatus.value, BookStatus.reading);
      expect(vm.isSearching.value, isFalse);
    });

    test('selectCategory(null) resets category filter', () {
      const cat = Category(
        id: 'cat1',
        name: '科幻',
        color: '#FF5722',
        sortOrder: 0,
        isSystem: false,
      );
      vm.selectCategory(cat);
      expect(vm.selectedCategory.value, isNotNull);

      vm.selectCategory(null);
      expect(vm.selectedCategory.value, isNull);
    });

    // ── 排序 ──

    test('default sort type is lastRead', () {
      expect(vm.defaultSortType.value, BookshelfSortType.lastRead);
    });

    // ── 视图模式 ──

    test('toggleViewMode switches isListView', () {
      expect(vm.isListView.value, isFalse);
      vm.toggleViewMode();
      expect(vm.isListView.value, isTrue);
      vm.toggleViewMode();
      expect(vm.isListView.value, isFalse);
    });

    // ── Android back button state ──

    test('selectCategory triggers after query with search cleared', () {
      vm.startSearch();
      vm.updateSearchKeyword('test');

      const cat = Category(
        id: 'cat1',
        name: '科幻',
        color: '#FF5722',
        sortOrder: 0,
        isSystem: false,
      );
      vm.selectCategory(cat);

      expect(vm.selectedCategory.value!.name, '科幻');
      expect(
        vm.isSearching.value,
        isFalse,
        reason: 'selecting category should exit search mode',
      );
    });

    test('back-to-back status filter works', () {
      vm.selectStatus(BookStatus.reading);
      expect(vm.selectedStatus.value, BookStatus.reading);

      vm.selectStatus(BookStatus.completed);
      expect(vm.selectedStatus.value, BookStatus.completed);

      vm.selectStatus(null);
      expect(vm.selectedStatus.value, isNull);
    });
  });
}
