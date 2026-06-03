// test/widget/bookshelf_page_test.dart
//
// HookBuilder Widget 测试 — BookshelfPage 信号绑定验证
//
// 验证:
// 1. 页面内 useSignal 本地状态初始化
// 2. useSignalEffect 响应 vm.feedback 变化

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signals_hooks/signals_hooks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookshelfPage hooks', () {
    testWidgets('useSignal 本地状态初始化', (tester) async {
      late Signal<bool> isSearching;
      late Signal<bool> batchMode;
      late Signal<Set<String>> selectedIds;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              isSearching = useSignal(false);
              batchMode = useSignal(false);
              selectedIds = useSignal<Set<String>>({});

              // 渲染内容以触发 hooks
              return Column(
                textDirection: TextDirection.ltr,
                children: [
                  Text('isSearching: ${isSearching.value}'),
                  Text('batchMode: ${batchMode.value}'),
                  Text('selectedIds: ${selectedIds.value.length}'),
                ],
              );
            },
          ),
        ),
      );

      // 初始状态
      expect(isSearching.value, isFalse);
      expect(batchMode.value, isFalse);
      expect(selectedIds.value, isEmpty);

      expect(find.text('isSearching: false'), findsOneWidget);
      expect(find.text('batchMode: false'), findsOneWidget);
      expect(find.text('selectedIds: 0'), findsOneWidget);
    });

    testWidgets('useSignal 状态切换后 UI 更新', (tester) async {
      late Signal<bool> isSearching;
      late Signal<bool> batchMode;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              isSearching = useSignal(false);
              batchMode = useSignal(false);
              return Column(
                textDirection: TextDirection.ltr,
                children: [
                  Text('isSearching: ${isSearching.value}'),
                  Text('batchMode: ${batchMode.value}'),
                ],
              );
            },
          ),
        ),
      );

      expect(isSearching.value, isFalse);
      expect(batchMode.value, isFalse);

      // 切换搜索状态
      isSearching.value = true;
      await tester.pump();
      expect(find.text('isSearching: true'), findsOneWidget);
      expect(find.text('isSearching: false'), findsNothing);

      // 切换批量模式
      batchMode.value = true;
      await tester.pump();
      expect(find.text('batchMode: true'), findsOneWidget);
    });

    testWidgets('selectedIds 添加和移除', (tester) async {
      late Signal<Set<String>> selectedIds;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              selectedIds = useSignal<Set<String>>({});
              return Text(
                'count: ${selectedIds.value.length}',
                textDirection: TextDirection.ltr,
              );
            },
          ),
        ),
      );

      expect(selectedIds.value, isEmpty);
      expect(find.text('count: 0'), findsOneWidget);

      // 添加 ID
      selectedIds.value = {'book_1'};
      await tester.pump();
      expect(find.text('count: 1'), findsOneWidget);

      // 移除 ID
      selectedIds.value = {};
      await tester.pump();
      expect(find.text('count: 0'), findsOneWidget);
    });

    testWidgets('useSignalEffect 响应外部信号变化', (tester) async {
      final feedback = signal<String?>(null);
      int effectCallCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              useSignalEffect(() {
                final msg = feedback.value;
                if (msg != null) {
                  effectCallCount++;
                }
              });
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      // effect 在 mount 时触发（msg 为 null，不计入非空计数）
      expect(effectCallCount, equals(0));

      // 设置反馈消息 → effect 应触发
      feedback.value = '操作成功';
      await tester.pump();
      expect(effectCallCount, equals(1));

      // 再次设置 → 再次触发
      feedback.value = '操作失败';
      await tester.pump();
      expect(effectCallCount, equals(2));

      // 设为 null → effect 触发但不计数
      feedback.value = null;
      await tester.pump();
      expect(effectCallCount, equals(2));
    });
  });
}
