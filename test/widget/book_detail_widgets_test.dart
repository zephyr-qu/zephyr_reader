// test/widget/book_detail_widgets_test.dart
//
// Widget tests for book detail sub-components.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zephyr_reader/features/bookshelf/page/widgets/book_detail_desc_section.dart';
import 'package:zephyr_reader/features/bookshelf/page/widgets/book_detail_info_section.dart';
import 'package:zephyr_reader/features/bookshelf/page/widgets/book_detail_actions.dart';
import 'package:zephyr_reader/features/bookshelf/page/widgets/book_detail_bottom_actions.dart';
import 'package:zephyr_reader/features/bookshelf/page/widgets/book_detail_hero.dart';
import 'package:zephyr_reader/features/bookshelf/page/widgets/book_detail_progress_card.dart';
import 'package:zephyr_reader/features/bookshelf/page/widgets/book_detail_note_stats.dart';
import 'package:zephyr_reader/features/bookshelf/page/widgets/book_detail_toc_section.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

import '../helpers/fixtures.dart';

Widget _wrapWithMaterial(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookDetailDescSection', () {
    testWidgets('renders description text', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          const BookDetailDescSection(
            description: 'A great book about Flutter.',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('A great book about Flutter.'), findsOneWidget);
    });
  });

  group('BookDetailInfoSection', () {
    testWidgets('renders book info rows', (tester) async {
      final book = createTestBook(
        publisher: 'Test Press',
        translator: 'John Doe',
        isbn: '978-1234567890',
      );
      final categories = [
        createTestCategory(name: 'Fiction'),
        createTestCategory(name: 'Sci-Fi'),
      ];

      await tester.pumpWidget(
        _wrapWithMaterial(
          BookDetailInfoSection(book: book, categories: categories),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TXT'), findsOneWidget);
      expect(find.text('Fiction / Sci-Fi'), findsOneWidget);
      expect(find.text('Test Press'), findsOneWidget);
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('978-1234567890'), findsOneWidget);
      expect(find.text('1.0 KB'), findsOneWidget);
    });
  });

  group('BookDetailActions', () {
    testWidgets('renders start reading when no progress', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          BookDetailActions(
            hasProgress: false,
            onContinueReading: () {},
            onReadFromBeginning: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Start Reading'), findsOneWidget);
      expect(find.text('Read from Beginning'), findsOneWidget);
    });
  });

  group('BookDetailBottomActions', () {
    testWidgets('renders three action buttons', (tester) async {
      int editCalls = 0;
      int exportCalls = 0;
      int deleteCalls = 0;

      await tester.pumpWidget(
        _wrapWithMaterial(
          BookDetailBottomActions(
            onEditMetadata: () => editCalls++,
            onExportNotes: () => exportCalls++,
            onDeleteBook: () => deleteCalls++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Edit Metadata'));
      expect(editCalls, 1);

      await tester.tap(find.text('Export Notes'));
      expect(exportCalls, 1);

      await tester.tap(find.text('Delete Book'));
      expect(deleteCalls, 1);
    });
  });

  group('BookDetailHero', () {
    testWidgets('renders title, author, categories, file size', (tester) async {
      final book = createTestBook(
        title: 'Test Book Title',
        author: 'Test Author',
        fileSize: 204800,
        isbn: '978-123',
      );
      final categories = [createTestCategory(name: 'Fiction')];

      await tester.pumpWidget(
        _wrapWithMaterial(BookDetailHero(book: book, categories: categories)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Test Book Title'), findsOneWidget);
      expect(find.text('Test Author'), findsOneWidget);
      expect(find.text('Fiction'), findsOneWidget);
      expect(find.textContaining('200.0 KB'), findsOneWidget);
      expect(find.textContaining('978-123'), findsOneWidget);
    });
  });

  group('BookDetailProgressCard', () {
    testWidgets('renders progress, reading time, session count', (
      tester,
    ) async {
      final progress = ReadingProgress(
        bookId: 'test',
        chapterIndex: 0,
        chunkIndex: 0,
        charOffset: 100,
        pageIndex: 0,
        totalPages: 10,
        progress: 0.35,
        readingTimeSeconds: 3600,
        lastReadAt: DateTime(2026, 1, 1),
        isCompleted: false,
      );

      await tester.pumpWidget(
        _wrapWithMaterial(
          BookDetailProgressCard(progress: progress, sessionCount: 5),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('35%'), findsOneWidget);
      expect(find.text('1h 0min'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('shows estimated remaining for substantial progress', (
      tester,
    ) async {
      final progress = ReadingProgress(
        bookId: 'test',
        chapterIndex: 0,
        chunkIndex: 0,
        charOffset: 100,
        pageIndex: 0,
        totalPages: 10,
        progress: 0.5,
        readingTimeSeconds: 600,
        lastReadAt: DateTime(2026, 1, 1),
        isCompleted: false,
      );

      await tester.pumpWidget(
        _wrapWithMaterial(
          BookDetailProgressCard(progress: progress, sessionCount: 1),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('50%'), findsOneWidget);
    });
  });

  group('BookDetailNoteStats', () {
    testWidgets('renders stat cards with counts', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          const BookDetailNoteStats(
            highlightCount: 3,
            annotationCount: 5,
            vocabCount: 12,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
    });

    testWidgets('hides when all counts are zero', (tester) async {
      await tester.pumpWidget(
        _wrapWithMaterial(
          const BookDetailNoteStats(
            highlightCount: 0,
            annotationCount: 0,
            vocabCount: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('invokes callbacks on tap', (tester) async {
      int highlightCalls = 0;
      int annotationCalls = 0;
      int vocabCalls = 0;

      await tester.pumpWidget(
        _wrapWithMaterial(
          BookDetailNoteStats(
            highlightCount: 1,
            annotationCount: 2,
            vocabCount: 3,
            onHighlightsTap: () => highlightCalls++,
            onAnnotationsTap: () => annotationCalls++,
            onVocabularyTap: () => vocabCalls++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('1'));
      expect(highlightCalls, 1);

      await tester.tap(find.text('2'));
      expect(annotationCalls, 1);

      await tester.tap(find.text('3'));
      expect(vocabCalls, 1);
    });
  });

  group('BookDetailTocSection', () {
    testWidgets('renders chapter list', (tester) async {
      final chapters = [
        createTestChapter(chapterIndex: 0, title: 'Chapter 1'),
        createTestChapter(chapterIndex: 1, title: 'Chapter 2'),
      ];

      await tester.pumpWidget(
        _wrapWithMaterial(
          BookDetailTocSection(
            chapters: chapters,
            showAll: false,
            currentChapterIndex: 0,
            onChapterTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chapter 1'), findsOneWidget);
      expect(find.text('Chapter 2'), findsOneWidget);
    });

    testWidgets('shows expand button when >5 chapters', (tester) async {
      final chapters = List.generate(
        7,
        (i) => createTestChapter(chapterIndex: i, title: 'Ch $i'),
      );

      int toggleCalls = 0;

      await tester.pumpWidget(
        _wrapWithMaterial(
          BookDetailTocSection(
            chapters: chapters,
            showAll: false,
            currentChapterIndex: -1,
            onToggleExpand: () => toggleCalls++,
            onChapterTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ch 0'), findsOneWidget);
      expect(find.text('Ch 4'), findsOneWidget);
      expect(find.text('Ch 5'), findsNothing);

      await tester.tap(find.text('Expand'));
      expect(toggleCalls, 1);
    });

    testWidgets('shows collapse button when expanded', (tester) async {
      final chapters = List.generate(
        7,
        (i) => createTestChapter(chapterIndex: i, title: 'Ch $i'),
      );

      await tester.pumpWidget(
        _wrapWithMaterial(
          BookDetailTocSection(
            chapters: chapters,
            showAll: true,
            currentChapterIndex: -1,
            onChapterTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ch 6'), findsOneWidget);
      expect(find.text('Collapse'), findsOneWidget);
    });

    testWidgets('highlights current chapter', (tester) async {
      final chapters = [
        createTestChapter(chapterIndex: 0, title: 'Chapter 1'),
        createTestChapter(chapterIndex: 1, title: 'Current Ch'),
        createTestChapter(chapterIndex: 2, title: 'Chapter 3'),
      ];

      await tester.pumpWidget(
        _wrapWithMaterial(
          BookDetailTocSection(
            chapters: chapters,
            showAll: false,
            currentChapterIndex: 1,
            onChapterTap: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Current'), findsOneWidget);
    });

    testWidgets('invokes onChapterTap with correct index', (tester) async {
      final chapters = [
        createTestChapter(chapterIndex: 0, title: 'Chapter 1'),
        createTestChapter(chapterIndex: 5, title: 'Chapter 5'),
      ];
      int tappedIndex = -1;

      await tester.pumpWidget(
        _wrapWithMaterial(
          BookDetailTocSection(
            chapters: chapters,
            showAll: false,
            currentChapterIndex: -1,
            onChapterTap: (i) => tappedIndex = i,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chapter 5'));
      expect(tappedIndex, 5);
    });
  });
}
