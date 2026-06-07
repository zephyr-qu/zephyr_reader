import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zephyr_reader/features/bookshelf/page/widgets/book_cover.dart';
import 'package:zephyr_reader/features/bookshelf/page/shelf/bookshelf_status_tabs.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

final _date = DateTime(2020);

final _testBook = Book(
  bookId: 'test_1',
  title: 'Test Book',
  author: 'Author',
  filePath: '/test/test.txt',
  fileSize: 1024,
  chapterCount: 10,
  totalCharacters: 50000,
  format: BookFormat.txt,
  addedAt: _date,
  status: BookStatus.reading,
  isPinned: false,
);

final _testBookNotReading = Book(
  bookId: 'test_2',
  title: 'Second Book',
  author: 'Author',
  filePath: '/test/test2.txt',
  fileSize: 512,
  chapterCount: 5,
  totalCharacters: 25000,
  format: BookFormat.txt,
  addedAt: _date,
  status: BookStatus.planned,
  isPinned: false,
);

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookCover', () {
    testWidgets('renders placeholder when no cover', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(width: 100, height: 150, child: BookCover(book: _testBook)),
        ),
      );
      await tester.pump();
      expect(find.byIcon(PhosphorIconsRegular.book), findsOneWidget);
      expect(find.text('Test Book'), findsOneWidget);
    });

    testWidgets('renders progress triangle', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 100,
            height: 150,
            child: BookCover(book: _testBook, progress: 0.65),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('65%'), findsOneWidget);
    });

    testWidgets('shows status tag when reading', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 100,
            height: 150,
            child: BookCover(book: _testBook, statusLabel: 'Reading'),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Reading'), findsOneWidget);
    });

    testWidgets('hides status tag when not reading', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 100,
            height: 150,
            child: BookCover(
              book: _testBookNotReading,
              statusLabel: 'Not Started',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Not Started'), findsNothing);
    });
  });

  group('BookshelfStatusTabs', () {
    testWidgets('renders all 4 tabs', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BookshelfStatusTabs(selectedStatus: null, onStatusChanged: (_) {}),
        ),
      );
      await tester.pump();
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Unread'), findsOneWidget);
      expect(find.text('Reading'), findsOneWidget);
      expect(find.text('Finished'), findsOneWidget);
    });

    testWidgets('tap calls callback', (tester) async {
      BookStatus? tapped;
      await tester.pumpWidget(
        _wrap(
          BookshelfStatusTabs(
            selectedStatus: null,
            onStatusChanged: (s) => tapped = s,
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('All'));
      expect(tapped, isNull);
      await tester.tap(find.text('Unread'));
      expect(tapped, BookStatus.planned);
    });
  });
}
