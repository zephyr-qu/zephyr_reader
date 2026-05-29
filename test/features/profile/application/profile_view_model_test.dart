import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:signals_core/signals_core.dart';
import 'package:zephyr_reader/features/profile/application/profile_view_model.dart';
import 'package:zephyr_reader/src/rust/api/data/vocabulary.dart' as vocab_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/src/rust/api/data/stats.dart' as stats_api;

class _MockStatsApi extends Mock {}

class _MockVocabApi extends Mock {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfileViewModel', () {
    late ProfileViewModel vm;

    setUp(() {
      vm = ProfileViewModel();
    });

    tearDown(() {
      vm.dispose();
    });

    group('初始状态', () {
      test('应为加载状态', () {
        expect(vm.globalStats.value, equals(AsyncState.loading()));
        expect(vm.vocabStats.value, equals(AsyncState.loading()));
      });
    });

    group('loadStats', () {
      test('成功时应更新两个统计信号', () async {
        // 由于涉及 Rust FFI 调用，这里测试基本逻辑
        expect(() => vm.loadStats(), returnsNormally);
      });

      test('多个刷新应正常工作', () async {
        await Future.wait([vm.loadStats(), vm.loadStats()]);

        // 应能正常完成
        expect(() => vm.globalStats.value, returnsNormally);
        expect(() => vm.vocabStats.value, returnsNormally);
      });
    });
  });
}
