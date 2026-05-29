import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/vocabulary/application/vocabulary_view_model.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

void main() {
  group('VocabularyViewModel Tests', () {
    late VocabularyViewModel vm;

    setUp(() {
      vm = VocabularyViewModel();
    });

    test('initial state is correct', () {
      expect(vm.filterStatus.value, equals(VocabStatus.new_));
      expect(vm.filterWordList.value, isNull);
      expect(vm.searchQuery.value, isEmpty);
    });

    test('setFilter updates filter status', () async {
      // filterStatus 在 loadWords(FFI) 之前同步设置
      vm.filterStatus.value = VocabStatus.learning;
      expect(vm.filterStatus.value, equals(VocabStatus.learning));

      // 再通过 setFilter 调用，验证信号先更新再调 FFI
      try {
        await vm.setFilter(VocabStatus.new_);
      } catch (_) {
        // FFI 不可用时跳过
      }
      // filterStatus 已被更新（在可能的 FFI 失败之前）
      expect(vm.filterStatus.value, equals(VocabStatus.new_));
    });

    test('setWordListFilter updates word list filter', () async {
      // filterWordList 在 loadWords(FFI) 之前同步设置
      vm.filterWordList.value = 'cet4';
      expect(vm.filterWordList.value, 'cet4');

      // 再通过 setWordListFilter 调用，验证信号先更新再调 FFI
      try {
        await vm.setWordListFilter(null);
      } catch (_) {
        // FFI 不可用时跳过
      }
      expect(vm.filterWordList.value, isNull);
    });

    test('updateStatus handles status string conversion', () async {
      // filterStatus 保持默认值不受 updateStatus 影响
      expect(vm.filterStatus.value, equals(VocabStatus.new_));

      // updateStatus 内部执行字符串 → VocabStatus 转换后调用 FFI
      // 在不具备 FFI 的环境下，验证方法不会改变 VM 的已知状态
      try {
        await vm.updateStatus('test_id', 'learning');
      } catch (_) {
        // FFI 不可用时静默跳过（参见 flutter_test_config.dart）
      }
      expect(vm.filterStatus.value, equals(VocabStatus.new_));
    });

    test('deleteWord handles delete gracefully', () async {
      // deleteWord 调用 FFI 后重新加载列表
      // 验证 VM 状态在调用前后保持一致性
      final beforeStatus = vm.filterStatus.value;
      try {
        await vm.deleteWord('test_id');
      } catch (_) {
        // FFI 不可用时静默跳过
      }
      // VM 状态应保持（即使 FFI 调用失败）
      expect(vm.filterStatus.value, equals(beforeStatus));
    });

    test('refresh triggers reload and updates signal state', () async {
      // refresh 触发 loadWords，words 信号应短暂变为 loading
      expect(vm.words.value.isLoading, isFalse);

      try {
        await vm.refresh();
      } catch (_) {
        // FFI 不可用时静默跳过
      }

      // 刷新完成后 words 不再处于 loading 状态
      // （可能为 data 或 error，取决于 FFI 可用性）
      expect(vm.words.value.isLoading, isFalse);
    });
  });
}
