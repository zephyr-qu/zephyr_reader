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

    test('selectedPeriod 初始为 today', () {
      final vm = ReadingStatsViewModel();
      expect(vm.selectedPeriod.value, equals(StatisticsPeriod.today));
    });

    test('goalMinutes 默认 60', () {
      final vm = ReadingStatsViewModel();
      expect(vm.goalMinutes.value, equals(60));
    });

    test('vocab 计数初始为 0', () {
      final vm = ReadingStatsViewModel();
      expect(vm.vocabUnstarted.value, equals(0));
      expect(vm.vocabLearning.value, equals(0));
      expect(vm.vocabMastered.value, equals(0));
      expect(vm.vocabIgnored.value, equals(0));
    });
  });

  group('ReadingStatsViewModel — 时段切换', () {
    test('selectedPeriod 可更新', () {
      final vm = ReadingStatsViewModel();
      vm.selectedPeriod.value = StatisticsPeriod.week;
      expect(vm.selectedPeriod.value, equals(StatisticsPeriod.week));
    });

    test('goalMinutes 可更新', () {
      final vm = ReadingStatsViewModel();
      vm.goalMinutes.value = 30;
      expect(vm.goalMinutes.value, equals(30));
    });

    test('dailyMinutes 派生自 dailyRecords', () {
      final vm = ReadingStatsViewModel();
      expect(vm.dailyMinutes.value, isEmpty);
    });
  });
}
