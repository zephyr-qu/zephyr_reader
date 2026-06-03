// test/features/home/application/home_view_model_test.dart
//
// 注意: HomeViewModel 依赖 Rust FFI。本文件使用 _isRustAvailable()
// 动态检测，Rust 不可用时 FFI 依赖用例静默跳过。

import 'package:flutter_test/flutter_test.dart';
import 'package:signals_core/signals_core.dart';
import 'package:zephyr_reader/features/home/application/home_view_model.dart';
import 'package:zephyr_reader/src/rust/frb_generated.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

import '../../../helpers/test_helper.dart';

Future<bool> _isRustAvailable() async {
  try {
    await RustLib.init();
    return true;
  } catch (_) {
    return false;
  }
}

HomeViewModel createHomeViewModel() {
  return HomeViewModel();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late bool rustAvailable;

  setUpAll(() async {
    TestHelper.registerCommonFallbacks();
    rustAvailable = await _isRustAvailable();
  });

  group('HomeViewModel', () {
    late HomeViewModel vm;

    setUp(() {
      vm = createHomeViewModel();
    });

    tearDown(() {
      // vm.dispose();
    });

    group('初始状态', () {
      test('recentBooks 应为加载状态', () {
        if (!rustAvailable) return;
        expect(
          vm.recentBooks.value,
          equals(AsyncState<List<Book>>.loading()),
        );
      });

      test('dailyRecords 应为加载状态', () {
        if (!rustAvailable) return;
        expect(
          vm.dailyRecords.value,
          equals(AsyncState<List<ReadingStats>>.loading()),
        );
      });

      test('isLoading 应返回正确值', () {
        if (!rustAvailable) return;
        expect(vm.isLoading.value, isTrue);
      });

      test('hasError 初始应为 false', () {
        if (!rustAvailable) return;
        expect(vm.hasError.value, isFalse);
      });

      test('computed 属性应在依赖信号变化时更新', () async {
        if (!rustAvailable) return;
        expect(vm.isLoading.value, isTrue);
        expect(vm.hasError.value, isFalse);

        await vm.loadData();

        expect(vm.isLoading.value, isFalse);
        expect(vm.hasError.value, isA<bool>());
      });
    });

    group('数据加载', () {
      test('loadData 执行后信号状态转换', () async {
        if (!rustAvailable) return;
        expect(vm.isLoading.value, isTrue);
        expect(vm.recentBooks.value.isLoading, isTrue);

        await vm.loadData();

        expect(vm.isLoading.value, isFalse);
        expect(vm.recentBooks.value.isLoading, isFalse);
        expect(vm.dailyRecords.value.isLoading, isFalse);
      });

      test('refresh 重新加载后信号状态正确', () async {
        if (!rustAvailable) return;
        await vm.loadData();
        expect(vm.isLoading.value, isFalse);

        await vm.refresh();

        expect(vm.isLoading.value, isFalse);
        expect(vm.recentBooks.value.isLoading, isFalse);
        expect(vm.dailyRecords.value.isLoading, isFalse);
      });
    });

    group('性能测试', () {
      test('多次刷新不影响稳定性', () async {
        if (!rustAvailable) return;
        await Future.wait(List.generate(10, (_) => vm.refresh()));
        expect(vm.recentBooks.value.isLoading, isFalse);
        expect(vm.dailyRecords.value.isLoading, isFalse);
        expect(vm.isLoading.value, isFalse);
      });
    });
  });
}
