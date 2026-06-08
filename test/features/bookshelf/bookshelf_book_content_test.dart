// test/features/bookshelf/bookshelf_book_content_test.dart
//
// BookshelfBookContent — 书架内容展示组件（无 FFI）
//
// 覆盖：加载态、错误态、空态、书籍列表、批量选择模式

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/presentation/widgets/skeleton_widget.dart';
import 'package:zephyr_reader/features/bookshelf/page/shelf/bookshelf_book_content.dart';
import 'package:zephyr_reader/features/bookshelf/page/widgets/book_cover.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

import '../../helpers/fixtures.dart';

Widget buildContent({
  bool isLoading = false,
  bool hasError = false,
  List<Book> books = const [],
  bool batchMode = false,
  Set<String> selectedIds = const {},
  int crossAxisCount = 3,
  Locale locale = const Locale('zh'),
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: BookshelfBookContent(
        isLoading: isLoading,
        hasError: hasError,
        books: books,
        crossAxisCount: crossAxisCount,
        batchMode: batchMode,
        selectedIds: selectedIds,
        onRetry: () {},
        onImportTap: () {},
        onRefresh: () {},
        onSelectionChanged: (_) {},
        onBookTap: (_) {},
        onBookLongPress: (_) {},
        readingProgress: const {},
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testBooks = createTestBooks(count: 3);

  group('BookshelfBookContent states', () {
    testWidgets('loading state shows skeleton grid', (tester) async {
      await tester.pumpWidget(buildContent(isLoading: true));
      await tester.pumpAndSettle();

      expect(find.byType(SkeletonGrid), findsOneWidget);
    });

    testWidgets('error state shows retry button', (tester) async {
      await tester.pumpWidget(buildContent(hasError: true));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      expect(find.text(l10n.loadFailed), findsOneWidget);
      expect(find.text(l10n.retry), findsOneWidget);
    });

    testWidgets('empty state shows import button', (tester) async {
      await tester.pumpWidget(buildContent(books: []));
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
      expect(find.text(l10n.bookshelfEmpty), findsOneWidget);
      expect(find.text(l10n.importBook), findsOneWidget);
    });

    testWidgets('book list shows book covers', (tester) async {
      await tester.pumpWidget(buildContent(books: testBooks));
      await tester.pumpAndSettle();

      expect(find.byType(BookCover), findsNWidgets(3));
    });

    testWidgets('book tap triggers callback', (tester) async {
      Book? tappedBook;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BookshelfBookContent(
              isLoading: false,
              hasError: false,
              books: testBooks,
              crossAxisCount: 3,
              batchMode: false,
              selectedIds: const {},
              onRetry: () {},
              onImportTap: () {},
              onRefresh: () {},
              onSelectionChanged: (_) {},
              onBookTap: (book) => tappedBook = book,
              onBookLongPress: (_) {},
              readingProgress: const {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Book Title 0'));
      await tester.pumpAndSettle();

      expect(tappedBook, isNotNull);
      expect(tappedBook!.title, 'Book Title 0');
    });

    testWidgets('batch mode shows selection circles', (tester) async {
      await tester.pumpWidget(buildContent(books: testBooks, batchMode: true));
      await tester.pumpAndSettle();

      expect(find.byIcon(PhosphorIconsRegular.circle), findsNWidgets(3));
    });

    testWidgets('batch mode with selection shows filled check', (tester) async {
      await tester.pumpWidget(
        buildContent(
          books: testBooks,
          batchMode: true,
          selectedIds: {'book_0', 'book_2'},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(PhosphorIconsFill.checkCircle), findsNWidgets(2));
      expect(find.byIcon(PhosphorIconsRegular.circle), findsOneWidget);
    });

    testWidgets('batch mode tap toggles selection', (tester) async {
      Set<String> selected = {};
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BookshelfBookContent(
              isLoading: false,
              hasError: false,
              books: testBooks,
              crossAxisCount: 3,
              batchMode: true,
              selectedIds: selected,
              onRetry: () {},
              onImportTap: () {},
              onRefresh: () {},
              onSelectionChanged: (ids) => selected = ids,
              onBookTap: (_) {},
              onBookLongPress: (_) {},
              readingProgress: const {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Book Title 0'));
      await tester.pumpAndSettle();

      expect(selected, contains('book_0'));
    });
  });
}
