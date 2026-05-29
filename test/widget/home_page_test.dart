// test/widget/home_page_test.dart
//
// HookBuilder Widget 测试 — HomePage 信号绑定验证
//
// 验证:
// 1. useSignalValue 绑定 ViewModel 信号
// 2. AsyncState 状态转换在 Hook 中的表现
// 3. computed 信号通过 Hook 传播

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomePage hooks', () {
    testWidgets('useSignalValue 绑定外部信号', (tester) async {
      final recentBooks = signal<AsyncState<List<Book>>>(AsyncState.loading());

      late AsyncState<List<Book>> boundValue;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              boundValue = useSignalValue(recentBooks);
              return Text(
                'loading: ${boundValue.isLoading}',
                textDirection: TextDirection.ltr,
              );
            },
          ),
        ),
      );

      expect(boundValue.isLoading, isTrue);
      expect(find.text('loading: true'), findsOneWidget);

      // 更新为 data 状态
      recentBooks.value = AsyncState.data(<Book>[]);
      await tester.pump();
      expect(boundValue.isLoading, isFalse);
      expect(boundValue.hasData, isTrue);
      expect(find.text('loading: false'), findsOneWidget);
    });

    testWidgets('useSignalValue 跟踪 AsyncState 生命周期', (tester) async {
      final dailyRecords = signal<AsyncState<List<ReadingStats>>>(
        AsyncState.loading(),
      );
      late AsyncState<List<ReadingStats>> bound;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              bound = useSignalValue(dailyRecords);
              return Column(
                children: [
                  Text(
                    'isLoading: ${bound.isLoading}',
                    textDirection: TextDirection.ltr,
                  ),
                  Text(
                    'hasData: ${bound.hasData}',
                    textDirection: TextDirection.ltr,
                  ),
                  Text(
                    'hasError: ${bound.hasError}',
                    textDirection: TextDirection.ltr,
                  ),
                ],
                textDirection: TextDirection.ltr,
              );
            },
          ),
        ),
      );

      // loading → error 转换
      dailyRecords.value = AsyncState.error(
        Exception('Network error'),
        StackTrace.current,
      );
      await tester.pump();
      expect(find.text('isLoading: false'), findsOneWidget);
      expect(find.text('hasData: false'), findsOneWidget);
      expect(find.text('hasError: true'), findsOneWidget);

      // error → data 转换
      dailyRecords.value = AsyncState.data(<ReadingStats>[]);
      await tester.pump();
      expect(find.text('isLoading: false'), findsOneWidget);
      expect(find.text('hasData: true'), findsOneWidget);
      expect(find.text('hasError: false'), findsOneWidget);
    });

    testWidgets('useSignalValue 空列表被视为 hasData', (tester) async {
      final records = signal<AsyncState<List<ReadingStats>>>(
        AsyncState.loading(),
      );

      late AsyncState<List<ReadingStats>> bound;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              bound = useSignalValue(records);
              return Text(
                'items: ${bound.hasData ? bound.data?.length ?? 0 : "n/a"}',
                textDirection: TextDirection.ltr,
              );
            },
          ),
        ),
      );

      // 空列表 → hasData: true, length: 0
      records.value = AsyncState.data(<ReadingStats>[]);
      await tester.pump();
      expect(find.text('items: 0'), findsOneWidget);
    });

    testWidgets('信号值在 rebuild 间保持', (tester) async {
      final counter = signal(0);

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              final val = useSignalValue(counter);
              return Text('count: $val', textDirection: TextDirection.ltr);
            },
          ),
        ),
      );

      expect(find.text('count: 0'), findsOneWidget);

      counter.value = 5;
      await tester.pump();
      expect(find.text('count: 5'), findsOneWidget);

      // 触发 rebuild
      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              final val = useSignalValue(counter);
              return Text('count: $val', textDirection: TextDirection.ltr);
            },
          ),
        ),
      );
      expect(find.text('count: 5'), findsOneWidget);
    });

    testWidgets('多信号独立绑定', (tester) async {
      final sigA = signal('A');
      final sigB = signal(0);

      late String valA;
      late int valB;

      await tester.pumpWidget(
        MaterialApp(
          home: HookBuilder(
            builder: (context) {
              valA = useSignalValue(sigA);
              valB = useSignalValue(sigB);
              return Text('$valA-$valB', textDirection: TextDirection.ltr);
            },
          ),
        ),
      );

      expect(find.text('A-0'), findsOneWidget);

      sigA.value = 'B';
      await tester.pump();
      expect(find.text('B-0'), findsOneWidget);

      sigB.value = 42;
      await tester.pump();
      expect(find.text('B-42'), findsOneWidget);
    });
  });
}
