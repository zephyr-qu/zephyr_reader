import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/statistics/application/reading_stats_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReadingStatsViewModel — 初始状态', () {
    test('globalStats 初始为 loading', () {
      final vm = ReadingStatsViewModel();
      expect(vm.globalStats.value.isLoading, isTrue);
    });

    test('dailyRecords 初始为 loading', () {
      final vm = ReadingStatsViewModel();
      expect(vm.dailyRecords.value.isLoading, isTrue);
    });

    test('vocab 计数初始为 0', () {
      final vm = ReadingStatsViewModel();
      final vs = vm.vocabStats.value;
      expect(vs.unstartedCount, equals(0));
      expect(vs.learningCount, equals(0));
      expect(vs.masteredCount, equals(0));
      expect(vs.ignoredCount, equals(0));
    });
  });
}
