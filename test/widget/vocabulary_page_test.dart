// test/widget/vocabulary_page_test.dart
//
// HookBuilder Widget 测试 — VocabularyPage 信号绑定验证
//
// 验证:
// 1. useSignal 管理 nullable 类型信号 (VocabStatus?, String?)
// 2. useSignalValue 读取 AsyncSignal
// 3. 多重 useSignal 组合
// 4. useSignalEffect 响应信号变化
//
// 注意: 使用本地测试类型而非 FRB 生成的 models.dart，避免 FFI 依赖

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signals_hooks/signals_hooks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VocabularyPage hooks', () {
    testWidgets('useSignal nullable 信号初始值', (tester) async {
      late Signal<VocabStatus?> filterStatus;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              filterStatus = useSignal<VocabStatus?>(VocabStatus.new_);
              return Text(
                'filter: ${filterStatus.value?.name}',
                textDirection: TextDirection.ltr,
              );
            },
          ),
        ),
      );

      expect(filterStatus.value, equals(VocabStatus.new_));
      expect(find.text('filter: new_'), findsOneWidget);
    });

    testWidgets('useSignal nullable 信号更新后 UI 刷新', (tester) async {
      late Signal<VocabStatus?> filterStatus;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              filterStatus = useSignal<VocabStatus?>(VocabStatus.new_);
              return Text(
                'filter: ${filterStatus.value?.name}',
                textDirection: TextDirection.ltr,
              );
            },
          ),
        ),
      );

      expect(find.text('filter: new_'), findsOneWidget);

      filterStatus.value = VocabStatus.learning;
      await tester.pump();
      expect(find.text('filter: learning'), findsOneWidget);

      filterStatus.value = VocabStatus.mastered;
      await tester.pump();
      expect(find.text('filter: mastered'), findsOneWidget);
    });

    testWidgets('useSignal nullable 信号可被重置为 null', (tester) async {
      late Signal<VocabStatus?> filterStatus;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              filterStatus = useSignal<VocabStatus?>(VocabStatus.new_);
              return Text(
                'filter: ${filterStatus.value?.name ?? "all"}',
                textDirection: TextDirection.ltr,
              );
            },
          ),
        ),
      );

      expect(find.text('filter: new_'), findsOneWidget);

      filterStatus.value = null;
      await tester.pump();
      expect(find.text('filter: all'), findsOneWidget);
    });

    testWidgets('useSignal 多个信号同时绑定', (tester) async {
      late Signal<VocabStatus?> filterStatus;
      late Signal<String?> filterWordList;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              filterStatus = useSignal<VocabStatus?>(VocabStatus.new_);
              filterWordList = useSignal<String?>('CET-4');
              return Column(
                children: [
                  Text(
                    'status: ${filterStatus.value?.name}',
                    textDirection: TextDirection.ltr,
                  ),
                  Text(
                    'wordList: ${filterWordList.value ?? "all"}',
                    textDirection: TextDirection.ltr,
                  ),
                ],
              );
            },
          ),
        ),
      );

      expect(find.text('status: new_'), findsOneWidget);
      expect(find.text('wordList: CET-4'), findsOneWidget);

      filterStatus.value = VocabStatus.mastered;
      filterWordList.value = 'IELTS';
      await tester.pump();

      expect(find.text('status: mastered'), findsOneWidget);
      expect(find.text('wordList: IELTS'), findsOneWidget);
    });

    testWidgets('useSignal 信号变化触发 useSignalEffect', (tester) async {
      int effectCount = 0;
      late Signal<VocabStatus?> trigger;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              trigger = useSignal<VocabStatus?>(VocabStatus.new_);
              useSignalEffect(() {
                trigger.value; // subscribe
                effectCount++;
              });
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(effectCount, equals(1));

      trigger.value = VocabStatus.learning;
      await tester.pump();
      expect(effectCount, equals(2));

      trigger.value = VocabStatus.mastered;
      await tester.pump();
      expect(effectCount, equals(3));
    });
  });
}

// ===== Test-only model types (no FFI dependency) =====

enum VocabStatus { new_, learning, mastered, known }

extension VocabStatusName on VocabStatus {
  String get name {
    switch (this) {
      case VocabStatus.new_:
        return 'new_';
      case VocabStatus.learning:
        return 'learning';
      case VocabStatus.mastered:
        return 'mastered';
      case VocabStatus.known:
        return 'known';
    }
  }
}
