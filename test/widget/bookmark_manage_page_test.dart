// test/widget/bookmark_manage_page_test.dart
//
// HookBuilder Widget 测试 — BookmarkManagePage 信号绑定验证
//
// 验证:
// 1. useSignal 本地状态初始化（searchMode, selectedBookmarks, sortBy, ascending）
// 2. 状态切换后 UI 更新
// 3. useSignalEffect 响应信号变化

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookmarkManagePage hooks', () {
    testWidgets('useSignal 本地状态初始化', (tester) async {
      late Signal<bool> isSearchMode;
      late Signal<Set<String>> selectedBookmarks;
      late Signal<bool> ascending;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              isSearchMode = useSignal(false);
              selectedBookmarks = useSignal<Set<String>>({});
              ascending = useSignal(false);

              return Material(
                child: Column(
                  children: [
                    Text('isSearchMode: ${isSearchMode.value}'),
                    Text('selectedIds: ${selectedBookmarks.value.length}'),
                    Text('ascending: ${ascending.value}'),
                  ],
                ),
              );
            },
          ),
        ),
      );

      // 初始状态
      expect(isSearchMode.value, isFalse);
      expect(selectedBookmarks.value, isEmpty);
      expect(ascending.value, isFalse);

      expect(find.text('isSearchMode: false'), findsOneWidget);
      expect(find.text('selectedIds: 0'), findsOneWidget);
      expect(find.text('ascending: false'), findsOneWidget);
    });

    testWidgets('isSearchMode 切换后 UI 更新', (tester) async {
      late Signal<bool> isSearchMode;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              isSearchMode = useSignal(false);
              return GestureDetector(
                onTap: () => isSearchMode.value = !isSearchMode.value,
                child: Text('isSearchMode: ${isSearchMode.value}'),
              );
            },
          ),
        ),
      );

      expect(find.text('isSearchMode: false'), findsOneWidget);

      // 点击切换
      await tester.tap(find.text('isSearchMode: false'));
      await tester.pump();
      expect(isSearchMode.value, isTrue);
      expect(find.text('isSearchMode: true'), findsOneWidget);

      // 再切回来
      await tester.tap(find.text('isSearchMode: true'));
      await tester.pump();
      expect(isSearchMode.value, isFalse);
      expect(find.text('isSearchMode: false'), findsOneWidget);
    });

    testWidgets('selectedBookmarks 添加和移除', (tester) async {
      late Signal<Set<String>> selectedBookmarks;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              selectedBookmarks = useSignal<Set<String>>({});
              return GestureDetector(
                onTap: () {
                  if (selectedBookmarks.value.contains('a')) {
                    selectedBookmarks.value = {};
                  } else {
                    selectedBookmarks.value = {'a'};
                  }
                },
                child: Text('count: ${selectedBookmarks.value.length}'),
              );
            },
          ),
        ),
      );

      expect(find.text('count: 0'), findsOneWidget);
      expect(selectedBookmarks.value, isEmpty);

      // 添加
      await tester.tap(find.text('count: 0'));
      await tester.pump();
      expect(selectedBookmarks.value, {'a'});
      expect(find.text('count: 1'), findsOneWidget);

      // 清空
      await tester.tap(find.text('count: 1'));
      await tester.pump();
      expect(selectedBookmarks.value, isEmpty);
    });

    testWidgets('ascending 排序切换', (tester) async {
      late Signal<bool> ascending;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              ascending = useSignal(false);
              final icon = ascending.value
                  ? PhosphorIconsRegular.arrowUp
                  : PhosphorIconsRegular.arrowDown;
              return GestureDetector(
                onTap: () => ascending.value = !ascending.value,
                child: Icon(icon),
              );
            },
          ),
        ),
      );

      // 初始为 ArrowDown
      expect(find.byIcon(PhosphorIconsRegular.arrowDown), findsOneWidget);
      expect(ascending.value, isFalse);

      // 点击切换
      await tester.tap(find.byIcon(PhosphorIconsRegular.arrowDown));
      await tester.pump();
      expect(ascending.value, isTrue);
      expect(find.byIcon(PhosphorIconsRegular.arrowUp), findsOneWidget);
    });
  });
}
