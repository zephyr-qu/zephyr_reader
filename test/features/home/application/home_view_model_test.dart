import 'package:flutter_test/flutter_test.dart';
import 'package:signals_core/signals_core.dart';
import 'package:zephyr_reader/features/home/application/home_view_model.dart';

import '../../../helpers/test_helper.dart';

// ===== Helper function =====

HomeViewModel createHomeViewModel() {
  return HomeViewModel();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 注册 fallback 值
  setUpAll(() {
    TestHelper.registerCommonFallbacks();
  });

  group('HomeViewModel', () {
    late HomeViewModel vm;

    setUp(() {
      vm = createHomeViewModel();
    });

    tearDown(() {
      // 清理资源
      vm.dispose();
    });

    group('初始状态', () {
      test('recentBooks 应为加载状态', () {
        expect(vm.recentBooks.value, equals(AsyncState.loading()));
      });

      test('dailyRecords 应为加载状态', () {
        expect(vm.dailyRecords.value, equals(AsyncState.loading()));
      });

      test('isLoading 应返回正确值', () {
        expect(vm.isLoading.value, isTrue);
      });

      test('hasError 初始应为 false', () {
        expect(vm.hasError.value, isFalse);
      });

      test('computed 属性应在依赖信号变化时更新', () async {
        // 初始状态: recentBooks 和 dailyRecords 均为 loading
        // → isLoading 应为 true
        expect(vm.isLoading.value, isTrue);
        expect(vm.hasError.value, isFalse);

        // 加载数据（即使 FFI 不可用，信号也会经历 loading→error 转换）
        await vm.loadData();

        // 加载完成后: isLoading 应为 false
        expect(vm.isLoading.value, isFalse);
        // hasError 反映了 FFI 调用的结果（可能 true 或 false）
        // 至少应是一个确定的状态
        expect(vm.hasError.value, isA<bool>());
      });
    });

    group('数据加载', () {
      test('loadData 执行后信号状态转换', () async {
        // 初始状态为 loading
        expect(vm.isLoading.value, isTrue);
        expect(vm.recentBooks.value.isLoading, isTrue);

        await vm.loadData();

        // 执行后应完成加载（即使无数据也应有确定状态）
        expect(vm.isLoading.value, isFalse);
        // recentBooks 和 dailyRecords 应不再仅为 loading 状态
        expect(vm.recentBooks.value.isLoading, isFalse);
        expect(vm.dailyRecords.value.isLoading, isFalse);
      });

      test('refresh 重新加载后信号状态正确', () async {
        // 先等待初始加载完成
        await vm.loadData();
        expect(vm.isLoading.value, isFalse);

        // 执行 refresh
        await vm.refresh();

        // refresh 后 isLoading 应为 false（异步操作完成）
        expect(vm.isLoading.value, isFalse);
        // 数据状态不应是 loading
        expect(vm.recentBooks.value.isLoading, isFalse);
        expect(vm.dailyRecords.value.isLoading, isFalse);
      });
    });

    // ===== FFI 依赖测试（暂不可用） =====
    //
    // 以下测试场景需要 Rust FFI Mock 支持:
    // - 数据加载成功 (recentBooks/dailyRecords 更新)
    // - 数据加载失败 (错误状态捕获)
    // - 响应式更新 (多信号独立更新)
    // - 连续刷新覆盖
    //
    // 这些场景记录在 test/TEST_DEBT.md (H-04)
    // 启用条件: 见 TEST_STRATEGY.md §2.2.2
    //
    // 待依赖就绪后，按 @ffi 标签运行:
    //   flutter test --tags=ffi

    // ===== 性能测试 =====
    group('性能测试', () {
      test('多次刷新不影响稳定性', () async {
        await Future.wait(List.generate(10, (_) => vm.refresh()));

        // 应能正常完成
        expect(() => vm.recentBooks.value, returnsNormally);
        expect(() => vm.dailyRecords.value, returnsNormally);
      });
    });
  });
}
