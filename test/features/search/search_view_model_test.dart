import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/search/application/search_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SearchViewModel Tests', () {
    late SearchViewModel vm;

    setUp(() {
      vm = SearchViewModel();
    });

    test('initial state is correct', () {
      expect(vm.keyword.value, isEmpty);
      expect(vm.isSearching.value, isFalse);
      expect(vm.currentPage.value, equals(1));
      expect(vm.hasMore.value, isFalse);
    });

    test('search with empty keyword clears results', () async {
      await vm.searchBook();
      expect(vm.results.value.value, isEmpty);
    });

    test('updateKeyword works correctly', () {
      vm.updateKeyword('test query');
      expect(vm.keyword.value, 'test query');
    });

    test('clear resets all state', () {
      vm.updateKeyword('test');
      vm.clear();

      expect(vm.keyword.value, isEmpty);
      expect(vm.currentPage.value, equals(1));
      expect(vm.searchResults.value, isNull);
      expect(vm.hasSearched.value, isFalse);
    });

    test('loadMore does nothing when hasMore is false', () async {
      vm.hasMore.value = false;
      await vm.loadMore();
      expect(vm.currentPage.value, equals(1));
    });
  });
}
