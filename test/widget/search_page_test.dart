// test/widget/search_page_test.dart
//
// HookBuilder Widget 测试 — SearchPage 信号绑定验证
//
// 验证:
// 1. useSignal / useComputed 本地状态
// 2. Hook 在 rebuild 间保持状态

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signals_hooks/signals_hooks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SearchPage hooks', () {
    testWidgets('useSignal 搜索文本初始为空', (tester) async {
      late Signal<String> searchText;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              searchText = useSignal('');
              return Text(
                'query: "${searchText.value}"',
                textDirection: TextDirection.ltr,
              );
            },
          ),
        ),
      );

      expect(searchText.value, isEmpty);
      expect(find.text('query: ""'), findsOneWidget);
    });

    testWidgets('useSignal 搜索文本更新', (tester) async {
      late Signal<String> searchText;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              searchText = useSignal('');
              return Text(
                'query: "${searchText.value}"',
                textDirection: TextDirection.ltr,
              );
            },
          ),
        ),
      );

      searchText.value = 'flutter';
      await tester.pump();
      expect(find.text('query: "flutter"'), findsOneWidget);

      searchText.value = 'dart';
      await tester.pump();
      expect(find.text('query: "dart"'), findsOneWidget);
    });

    testWidgets('useComputed 派生状态', (tester) async {
      late Signal<String> query;
      late ReadonlySignal<bool> hasQuery;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              query = useSignal('');
              hasQuery = useComputed(() => query.value.isNotEmpty);
              return Text(
                'hasQuery: $hasQuery',
                textDirection: TextDirection.ltr,
              );
            },
          ),
        ),
      );

      expect(hasQuery.value, isFalse);
      expect(find.text('hasQuery: false'), findsOneWidget);

      query.value = 'test';
      await tester.pump();
      expect(hasQuery.value, isTrue);
      expect(find.text('hasQuery: true'), findsOneWidget);

      query.value = '';
      await tester.pump();
      expect(hasQuery.value, isFalse);
      expect(find.text('hasQuery: false'), findsOneWidget);
    });

    testWidgets('多重信号组合', (tester) async {
      late Signal<bool> isSearching;
      late Signal<bool> hasSearched;
      late Signal<String?> searchError;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              isSearching = useSignal(false);
              hasSearched = useSignal(false);
              searchError = useSignal<String?>(null);

              final status = isSearching.value
                  ? 'searching'
                  : hasSearched.value
                  ? searchError.value != null
                        ? 'error'
                        : 'done'
                  : 'idle';

              return Text('status: $status', textDirection: TextDirection.ltr);
            },
          ),
        ),
      );

      expect(find.text('status: idle'), findsOneWidget);

      isSearching.value = true;
      await tester.pump();
      expect(find.text('status: searching'), findsOneWidget);

      isSearching.value = false;
      hasSearched.value = true;
      await tester.pump();
      expect(find.text('status: done'), findsOneWidget);

      searchError.value = 'Network error';
      await tester.pump();
      expect(find.text('status: error'), findsOneWidget);
    });
  });
}
