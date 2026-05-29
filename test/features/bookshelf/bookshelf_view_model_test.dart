import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr_reader/features/bookshelf/application/bookshelf_view_model.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookshelfViewModel Tests', () {
    late BookshelfViewModel vm;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      vm = BookshelfViewModel(prefs);
    });

    test('initial state is correct', () {
      expect(vm.isSearching.value, isFalse);
      expect(vm.searchKeyword.value, isEmpty);
      expect(vm.selectedCategory.value, isNull);
      expect(vm.selectedStatus.value, isNull);
    });

    test('search keyword updates correctly', () {
      vm.updateSearchKeyword('test');
      expect(vm.searchKeyword.value, 'test');
    });

    test('start and stop search works', () {
      vm.startSearch();
      expect(vm.isSearching.value, isTrue);

      vm.stopSearch();
      expect(vm.isSearching.value, isFalse);
      expect(vm.searchKeyword.value, isEmpty);
    });

    test('select category works', () {
      final category = const Category(
        id: 'cat1',
        name: 'Test Category',
        color: '#FF5722',
        sortOrder: 0,
        isSystem: false,
      );
      vm.selectCategory(category);
      expect(vm.selectedCategory.value, equals(category));
      expect(vm.isSearching.value, isFalse);
    });

    test('select status works', () {
      vm.selectStatus(BookStatus.reading);
      expect(vm.selectedStatus.value, equals(BookStatus.reading));
    });
  });
}
