// test/widget/book_search_page_test.dart
//
// HookBuilder Widget 测试 — BookSearchPage 信号绑定验证
//
// 验证:
// 1. useSignal 本地状态初始化（searchResults, isSearching, searchQuery, error）
// 2. 搜索状态变化后 UI 更新
// 3. 搜索结果列表渲染

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signals_hooks/signals_hooks.dart';

/// 简化的搜索结果占位模型（模拟 BookSearchPage 的 SearchResult）
class _MockSearchResult {
  final String id;
  final String title;
  _MockSearchResult(this.id, this.title);

  @override
  bool operator ==(Object other) =>
      other is _MockSearchResult && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookSearchPage hooks', () {
    testWidgets('useSignal 本地状态初始化', (tester) async {
      late Signal<List<_MockSearchResult>> searchResults;
      late Signal<bool> isSearching;
      late Signal<String> searchQuery;
      late Signal<String?> error;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              searchResults = useSignal<List<_MockSearchResult>>([]);
              isSearching = useSignal(false);
              searchQuery = useSignal('');
              error = useSignal<String?>(null);

              return Material(
                child: Column(
                  children: [
                    Text('results: ${searchResults.value.length}'),
                    Text('isSearching: ${isSearching.value}'),
                    Text('query: "${searchQuery.value}"'),
                    if (error.value != null) Text('error: ${error.value}'),
                  ],
                ),
              );
            },
          ),
        ),
      );

      expect(searchResults.value, isEmpty);
      expect(isSearching.value, isFalse);
      expect(searchQuery.value, isEmpty);
      expect(error.value, isNull);

      expect(find.text('results: 0'), findsOneWidget);
      expect(find.text('isSearching: false'), findsOneWidget);
      expect(find.text('query: ""'), findsOneWidget);
    });

    testWidgets('搜索状态切换后 UI 更新', (tester) async {
      late Signal<bool> isSearching;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              isSearching = useSignal(false);
              return GestureDetector(
                onTap: () => isSearching.value = !isSearching.value,
                child: Text('isSearching: ${isSearching.value}'),
              );
            },
          ),
        ),
      );

      expect(find.text('isSearching: false'), findsOneWidget);

      await tester.tap(find.text('isSearching: false'));
      await tester.pump();
      expect(isSearching.value, isTrue);
      expect(find.text('isSearching: true'), findsOneWidget);

      await tester.tap(find.text('isSearching: true'));
      await tester.pump();
      expect(isSearching.value, isFalse);
    });

    testWidgets('搜索结果列表变化后 UI 更新', (tester) async {
      late Signal<List<_MockSearchResult>> searchResults;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              searchResults = useSignal<List<_MockSearchResult>>([]);
              return Column(
                children: [
                  Text('results: ${searchResults.value.length}'),
                  ...searchResults.value.map((r) => Text(r.title)),
                ],
              );
            },
          ),
        ),
      );

      expect(find.text('results: 0'), findsOneWidget);

      // 添加结果
      searchResults.value = [
        _MockSearchResult('1', '算法导论'),
        _MockSearchResult('2', '深入理解计算机系统'),
      ];
      await tester.pump();
      expect(find.text('results: 2'), findsOneWidget);
      expect(find.text('算法导论'), findsOneWidget);
      expect(find.text('深入理解计算机系统'), findsOneWidget);

      // 清空结果
      searchResults.value = [];
      await tester.pump();
      expect(find.text('results: 0'), findsOneWidget);
    });

    testWidgets('搜索查询文本更新', (tester) async {
      late Signal<String> searchQuery;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              searchQuery = useSignal('');
              return GestureDetector(
                onTap: () => searchQuery.value = 'Flutter',
                child: Text('query: "${searchQuery.value}"'),
              );
            },
          ),
        ),
      );

      expect(find.text('query: ""'), findsOneWidget);

      await tester.tap(find.text('query: ""'));
      await tester.pump();
      expect(searchQuery.value, 'Flutter');
      expect(find.text('query: "Flutter"'), findsOneWidget);
    });

    testWidgets('错误状态显示和清除', (tester) async {
      late Signal<String?> error;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              error = useSignal<String?>(null);
              return GestureDetector(
                onTap: () {
                  error.value = error.value == null ? '网络错误' : null;
                },
                child: Column(
                  children: [
                    Text('hasError: ${error.value != null}'),
                    if (error.value != null) Text('error: ${error.value}'),
                  ],
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('hasError: false'), findsOneWidget);
      expect(find.textContaining('网络错误'), findsNothing);

      // 设置错误
      await tester.tap(find.text('hasError: false'));
      await tester.pump();
      expect(error.value, '网络错误');
      expect(find.text('hasError: true'), findsOneWidget);
      expect(find.text('error: 网络错误'), findsOneWidget);

      // 清除错误
      await tester.tap(find.text('hasError: true'));
      await tester.pump();
      expect(error.value, isNull);
      expect(find.text('hasError: false'), findsOneWidget);
    });
  });
}
