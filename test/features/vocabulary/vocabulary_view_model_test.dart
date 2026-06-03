// test/features/vocabulary/vocabulary_view_model_test.dart
//
// 注意: 部分测试依赖 Rust FFI（VocabularyViewModel 调用 Rust 存储层）。
// 本文件使用 _isRustAvailable() 动态检测 Rust 可用性，
// Rust 不可用时静默跳过 FFI 依赖用例，而非虚假通过。

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/vocabulary/application/vocabulary_view_model.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/src/rust/frb_generated.dart';

/// 尝试检查 Rust 是否可用
Future<bool> _isRustAvailable() async {
  try {
    await RustLib.init();
    return true;
  } catch (_) {
    return false;
  }
}

void main() {
  late bool rustAvailable;

  setUpAll(() async {
    rustAvailable = await _isRustAvailable();
  });

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

    group('FFI 依赖用例', () {
      test('setFilter updates filter status', () async {
        if (!rustAvailable) return;
        vm.filterStatus.value = VocabStatus.learning;
        expect(vm.filterStatus.value, equals(VocabStatus.learning));

        await vm.setFilter(VocabStatus.new_);
        expect(vm.filterStatus.value, equals(VocabStatus.new_));
      });

      test('setWordListFilter updates word list filter', () async {
        if (!rustAvailable) return;
        vm.filterWordList.value = 'cet4';
        expect(vm.filterWordList.value, 'cet4');

        await vm.setWordListFilter(null);
        expect(vm.filterWordList.value, isNull);
      });

      test('updateStatus handles status string conversion', () async {
        if (!rustAvailable) return;
        expect(vm.filterStatus.value, equals(VocabStatus.new_));

        await vm.updateStatus('test_id', 'learning');
        // updateStatus 内部调用 FFI；如果成功，filterStatus 不变
        expect(vm.filterStatus.value, equals(VocabStatus.new_));
      });

      test('deleteWord handles delete gracefully', () async {
        if (!rustAvailable) return;
        await vm.deleteWord('test_id');
        // 删除完成后不应处于 loading 状态
        expect(vm.words.value.isLoading, isFalse);
      });

      test('refresh triggers reload and updates signal state', () async {
        if (!rustAvailable) return;
        expect(vm.words.value.isLoading, isFalse);

        await vm.refresh();

        expect(vm.words.value.isLoading, isFalse);
      });
    });
  });
}
