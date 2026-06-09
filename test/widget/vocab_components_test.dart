// test/widget/vocab_components_test.dart
//
// 生词页面提取的三个 StatelessWidget 的渲染和交互测试。
// 不依赖 Rust FFI，纯 UI 验证。

import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/l10n/app_localizations_en.dart';
import 'package:zephyr_reader/features/vocabulary/page/widgets/vocab_status_chip.dart';
import 'package:zephyr_reader/features/vocabulary/page/widgets/vocab_list_item_tile.dart';
import 'package:zephyr_reader/features/vocabulary/page/widgets/vocab_stats_row.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

final testL10n = AppLocalizationsEn();

Widget wrapWithTheme(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
    home: Scaffold(body: child),
  );
}

/// Helper to create a test Vocab with overridable fields.
Vocab createTestVocabItem({
  String id = 'test-id',
  String word = '测试词',
  String pinyin = 'ce shi ci',
  String translation = 'test word',
  String? bookId,
  VocabStatus status = VocabStatus.learning,
  String? wordList,
}) {
  return Vocab(
    id: id,
    word: word,
    pinyin: pinyin,
    translation: translation,
    contextSentence: null,
    bookId: bookId,
    chapterIndex: null,
    charOffset: null,
    createdAt: DateTime.now(),
    reviewCount: 0,
    lastReviewedAt: null,
    status: status,
    wordList: wordList,
    dictSource: null,
    dictEntryHash: null,
  );
}

/// Pump past flutter_animate animation timers to avoid pending-timer assertion.
Future<void> flushAnimations(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VocabStatusChip', () {
    for (final status in VocabStatus.values) {
      testWidgets('渲染 ${vocabStatusLabel(status, testL10n)} 标签', (tester) async {
        await tester.pumpWidget(
          wrapWithTheme(
            VocabStatusChip(status: status),
          ),
        );

        expect(find.text(vocabStatusLabel(status, testL10n)), findsOneWidget);
      });
    }
  });

  group('VocabListItemTile', () {
    testWidgets('渲染词条基本内容和状态标签', (tester) async {
      final item = createTestVocabItem();

      await tester.pumpWidget(
        wrapWithTheme(
          VocabListItemTile(
            item: item,
            bookTitles: const {},
            index: 0,
            onDismissed: () {},
            onUpdateStatus: (_) {},
          ),
        ),
      );

      expect(find.text('测试词'), findsOneWidget);
      expect(find.text(testL10n.statusLearning), findsOneWidget);
      expect(find.text('/ce shi ci/'), findsOneWidget);
      await flushAnimations(tester);
    });

    testWidgets('渲染 translation 翻译内容', (tester) async {
      final item = createTestVocabItem(translation: 'test translation');

      await tester.pumpWidget(
        wrapWithTheme(
          VocabListItemTile(
            item: item,
            bookTitles: const {},
            index: 0,
            onDismissed: () {},
            onUpdateStatus: (_) {},
          ),
        ),
      );

      expect(find.text('test translation'), findsOneWidget);
      await flushAnimations(tester);
    });

    testWidgets('渲染 wordList badge 标签', (tester) async {
      final item = createTestVocabItem(wordList: 'CET-4');

      await tester.pumpWidget(
        wrapWithTheme(
          VocabListItemTile(
            item: item,
            bookTitles: const {},
            index: 0,
            onDismissed: () {},
            onUpdateStatus: (_) {},
          ),
        ),
      );

      expect(find.text('CET-4'), findsOneWidget);
      await flushAnimations(tester);
    });

    testWidgets('渲染 bookTitle 来自书籍映射', (tester) async {
      final item = createTestVocabItem(bookId: 'book_1');

      await tester.pumpWidget(
        wrapWithTheme(
          VocabListItemTile(
            item: item,
            bookTitles: const {'book_1': '测试书籍'},
            index: 0,
            onDismissed: () {},
            onUpdateStatus: (_) {},
          ),
        ),
      );

      expect(find.text('测试书籍'), findsOneWidget);
      await flushAnimations(tester);
    });

    testWidgets('无拼音时隐藏拼音', (tester) async {
      final item = createTestVocabItem(pinyin: '', translation: 'word');

      await tester.pumpWidget(
        wrapWithTheme(
          VocabListItemTile(
            item: item,
            bookTitles: const {},
            index: 0,
            onDismissed: () {},
            onUpdateStatus: (_) {},
          ),
        ),
      );

      expect(find.text('word'), findsOneWidget);
      expect(find.text(testL10n.statusLearning), findsOneWidget);
      expect(find.text('/ce shi ci/'), findsNothing);
      await flushAnimations(tester);
    });

    testWidgets('无 bookId 和 wordList 时不渲染 meta row', (tester) async {
      final item = createTestVocabItem(bookId: null, wordList: null);

      await tester.pumpWidget(
        wrapWithTheme(
          VocabListItemTile(
            item: item,
            bookTitles: const {},
            index: 0,
            onDismissed: () {},
            onUpdateStatus: (_) {},
          ),
        ),
      );

      expect(find.text('测试词'), findsOneWidget);
      expect(find.text('test word'), findsOneWidget);
      expect(find.text(testL10n.statusLearning), findsOneWidget);
      expect(find.byIcon(Icons.book), findsNothing);
      await flushAnimations(tester);
    });

    testWidgets('Dismissible 滑动出现确认弹窗', (tester) async {
      final item = createTestVocabItem(word: 'delete-me');

      bool dismissed = false;
      await tester.pumpWidget(
        wrapWithTheme(
          VocabListItemTile(
            item: item,
            bookTitles: const {},
            index: 0,
            onDismissed: () => dismissed = true,
            onUpdateStatus: (_) {},
          ),
        ),
      );

      // 左滑删除
      await tester.fling(find.text('delete-me'), const Offset(-500, 0), 1000);
      await tester.pumpAndSettle();

      // 确认弹窗应出现
      expect(find.text(testL10n.confirmDelete), findsOneWidget);
      expect(find.text(testL10n.cancel), findsOneWidget);
      expect(find.text(testL10n.delete), findsOneWidget);

      // 点击取消，不应删除
      await tester.tap(find.text(testL10n.cancel));
      await tester.pumpAndSettle();
      expect(dismissed, isFalse);

      // 再次左滑
      await tester.fling(find.text('delete-me'), const Offset(-500, 0), 1000);
      await tester.pumpAndSettle();

      // 点击确认删除
      await tester.tap(find.text(testL10n.delete));
      await tester.pumpAndSettle();
      expect(dismissed, isTrue);
      await flushAnimations(tester);
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
            stats: AsyncState.data(stats),
            filterStatus: null,
            filterWordList: null,
            wordLists: const ['CET-4', 'CET-6'],
            onFilterChanged: (_) {},
            onWordListFilterChanged: (_) {},
          ),
        ),
      );

      expect(find.text('All 100'), findsOneWidget);
      expect(find.text('Unlearned 40'), findsOneWidget);
      expect(find.text('Learning 30'), findsOneWidget);
      expect(find.text('Ignored 10'), findsOneWidget);
      expect(find.text('Mastered 20'), findsOneWidget);
      expect(find.text('All Word Lists'), findsOneWidget);
      expect(find.text('CET-4'), findsOneWidget);
      expect(find.text('CET-6'), findsOneWidget);
    });

    testWidgets('stats 为 null 时占位', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          VocabStatsRow(
            stats: AsyncState.loading(),
            filterStatus: null,
            filterWordList: null,
            wordLists: const ['CET-4'],
            onFilterChanged: (_) {},
            onWordListFilterChanged: (_) {},
          ),
        ),
      );

      expect(find.text('All 0'), findsNothing);
    });

    testWidgets('filterStatus 选中状态高亮', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          VocabStatsRow(
            stats: AsyncState.data(stats),
            filterStatus: VocabStatus.learning,
            filterWordList: null,
            wordLists: const [],
            onFilterChanged: (_) {},
            onWordListFilterChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Learning 30'), findsOneWidget);
      expect(find.text('Unlearned 40'), findsOneWidget);
    });
  });
}
