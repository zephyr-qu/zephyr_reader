import 'package:flutter_test/flutter_test.dart';
import 'package:signals_core/signals_core.dart';
import 'package:zephyr_reader/features/home/application/home_view_model.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomeViewModel — 初始状态', () {
    test('recentBooks 初始为 loading', () {
      final vm = HomeViewModel();
      expect(vm.recentBooks.value, equals(AsyncState<List<Book>>.loading()));
    });

    test('dailyRecords 初始为 loading', () {
      final vm = HomeViewModel();
      expect(
        vm.dailyRecords.value,
        equals(AsyncState<List<ReadingStats>>.loading()),
      );
    });

    test('isLoading 初始为 true', () {
      final vm = HomeViewModel();
      expect(vm.isLoading.value, isTrue);
    });

    test('hasError 初始为 false', () {
      final vm = HomeViewModel();
      expect(vm.hasError.value, isFalse);
    });

    test('dispose 后可安全释放', () {
      final vm = HomeViewModel();
      vm.dispose();
    });
  });
}
