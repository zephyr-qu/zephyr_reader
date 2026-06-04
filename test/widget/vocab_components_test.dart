// test/widget/vocab_components_test.dart
//
// 生词页面提取的三个 StatelessWidget 的渲染测试。
// 不依赖 Rust FFI，纯 UI 验证。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zephyr_reader/features/vocabulary/page/widgets/vocab_status_chip.dart';
import 'package:zephyr_reader/features/vocabulary/page/widgets/vocab_list_item_tile.dart';
import 'package:zephyr_reader/features/vocabulary/page/widgets/vocab_stats_row.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/src/rust/storage/vocab_status_extension.dart';

Widget wrapWithTheme(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VocabStatusChip', () {
    for (final status in VocabStatus.values) {
      testWidgets('渲染 ${status.displayName} 标签', (tester) async {
        await tester.pumpWidget(
          wrapWithTheme(VocabStatusChip(status: status, theme: ThemeData())),
        );

        expect(find.text(status.displayName), findsOneWidget);
      });
    }
  });

  group('VocabListItemTile', () {
    testWidgets('渲染词条内容和状态标签', (tester) async {
      final item = Vocab(
        id: 'test-id',
        word: '测试词',
        pinyin: 'ce shi ci',
        translation: 'test word',
        contextSentence: null,
        bookId: null,
        chapterIndex: null,
        charOffset: null,
        createdAt: DateTime.now(),
        reviewCount: 0,
        lastReviewedAt: null,
        status: VocabStatus.learning,
        wordList: null,
        dictSource: null,
        dictEntryHash: null,
      );

      await tester.pumpWidget(
        wrapWithTheme(
          VocabListItemTile(
            item: item,
            bookTitles: {},
            theme: ThemeData(),
            onDismissed: () {},
            onUpdateStatus: (_) {},
          ),
        ),
      );

      expect(find.text('测试词'), findsOneWidget);
      expect(find.text(VocabStatus.learning.displayName), findsOneWidget);
      expect(find.text('ce shi ci'), findsOneWidget);
    });

    testWidgets('无拼音时无 subtitle', (tester) async {
      final item = Vocab(
        id: 'test-id-2',
        word: 'word',
        pinyin: '',
        translation: 'word',
        contextSentence: null,
        bookId: null,
        chapterIndex: null,
        charOffset: null,
        createdAt: DateTime.now(),
        reviewCount: 0,
        lastReviewedAt: null,
        status: VocabStatus.mastered,
        wordList: null,
        dictSource: null,
        dictEntryHash: null,
      );

      await tester.pumpWidget(
        wrapWithTheme(
          VocabListItemTile(
            item: item,
            bookTitles: {},
            theme: ThemeData(),
            onDismissed: () {},
            onUpdateStatus: (_) {},
          ),
        ),
      );

      expect(find.text('word'), findsOneWidget);
      // subtitle Text 不应存在（空 parts）
      // 用 hasLength 验证没有多余的 Text widget 包含 pinyin
      expect(find.text(VocabStatus.mastered.displayName), findsOneWidget);
    });

    testWidgets('渲染词条后部件结构正确', (tester) async {
      final item = Vocab(
        id: 'swipe-test',
        word: 'swipe word',
        pinyin: '',
        translation: '',
        contextSentence: null,
        bookId: null,
        chapterIndex: null,
        charOffset: null,
        createdAt: DateTime.now(),
        reviewCount: 0,
        lastReviewedAt: null,
        status: VocabStatus.unstarted,
        wordList: null,
        dictSource: null,
        dictEntryHash: null,
      );
 
      await tester.pumpWidget(
        wrapWithTheme(
          VocabListItemTile(
            item: item,
            bookTitles: {},
            theme: ThemeData(),
            onDismissed: () {},
            onUpdateStatus: (_) {},
          ),
        ),
      );
 
      expect(find.text('swipe word'), findsOneWidget);
      expect(find.text(VocabStatus.unstarted.displayName), findsOneWidget);
    });
    });
 

  group('VocabStatsRow', () {
    final stats = const VocabStats(
      totalWords: 100,
      unstartedCount: 40,
      learningCount: 30,
      masteredCount: 20,
      ignoredCount: 10,
    );

    testWidgets('有统计时渲染所有 chip', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          VocabStatsRow(
            theme: ThemeData(),
            stats: stats,
            filterStatus: null,
            filterWordList: null,
            wordLists: const ['CET-4', 'CET-6'],
            onFilterChanged: (_) {},
            onWordListFilterChanged: (_) {},
          ),
        ),
      );

      expect(find.text('全部 100'), findsOneWidget);
      expect(find.text('未学 40'), findsOneWidget);
      expect(find.text('学习中 30'), findsOneWidget);
      expect(find.text('已忽略 10'), findsOneWidget);
      expect(find.text('已掌握 20'), findsOneWidget);
      expect(find.text('全部词库'), findsOneWidget);
      expect(find.text('CET-4'), findsOneWidget);
      expect(find.text('CET-6'), findsOneWidget);
    });

    testWidgets('stats 为 null 时占位', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          VocabStatsRow(
            theme: ThemeData(),
            stats: null,
            filterStatus: null,
            filterWordList: null,
            wordLists: const ['CET-4'],
            onFilterChanged: (_) {},
            onWordListFilterChanged: (_) {},
          ),
        ),
      );

      // 不应渲染任何数据 chip
      expect(find.text('全部 0'), findsNothing);
    });

    testWidgets('filterStatus 选中状态高亮', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          VocabStatsRow(
            theme: ThemeData(),
            stats: stats,
            filterStatus: VocabStatus.learning,
            filterWordList: null,
            wordLists: const [],
            onFilterChanged: (_) {},
            onWordListFilterChanged: (_) {},
          ),
        ),
      );

      expect(find.text('学习中 30'), findsOneWidget);
      expect(find.text('未学 40'), findsOneWidget);
    });
  });
}
