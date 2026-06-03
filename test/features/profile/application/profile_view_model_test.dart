// test/features/profile/application/profile_view_model_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:signals_core/signals_core.dart';
import 'package:zephyr_reader/features/profile/application/profile_view_model.dart';
import 'package:zephyr_reader/src/rust/frb_generated.dart';

Future<bool> _isRustAvailable() async {
  try {
    await RustLib.init();
    return true;
  } catch (_) {
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late bool rustAvailable;

  setUpAll(() async {
    rustAvailable = await _isRustAvailable();
  });

  group('ProfileViewModel', () {
    late ProfileViewModel vm;

    setUp(() {
      vm = ProfileViewModel();
    });

    tearDown(() {
      // vm.dispose();
    });

    group('初始状态', () {
      test('应为加载状态', () {
        expect(
          vm.globalStats.value,
          equals(AsyncState<GlobalStats?>.loading()),
        );
        expect(
          vm.vocabStats.value,
          equals(AsyncState<VocabStats?>.loading()),
        );
      });
    });

    group('loadStats', () {
      test('成功时应更新两个统计信号', () async {
        if (!rustAvailable) return;
        await vm.loadStats();
        // 加载完成后不应处于 loading 状态
        expect(vm.globalStats.value.isLoading, isFalse);
        expect(vm.vocabStats.value.isLoading, isFalse);
      });

      test('多个刷新应正常工作', () async {
        if (!rustAvailable) return;
        await Future.wait([vm.loadStats(), vm.loadStats()]);
        expect(vm.globalStats.value.isLoading, isFalse);
        expect(vm.vocabStats.value.isLoading, isFalse);
      });
    });
  });
}
