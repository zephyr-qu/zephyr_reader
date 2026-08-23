import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';
import 'package:zephyr_reader/features/reader/page/toolbar/reader_bookmark_sheet.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/domain/bookmark/models.dart';

void main() {
  Widget buildSheet({
    List<Bookmark> bookmarks = const [],
    double textScaleFactor = 1,
    ValueChanged<Bookmark>? onSelect,
    Future<void> Function(Bookmark)? onDelete,
  }) {
    return MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(
            size: const Size(320, 320),
            textScaler: TextScaler.linear(textScaleFactor),
          ),
          child: ReaderBookmarkDrawer(
            bookmarks: bookmarks,
            readerTheme: ReaderThemeExtension.light(),
            onSelect: onSelect ?? (_) {},
            onDelete: onDelete ?? (_) async {},
          ),
        ),
      ),
    );
  }

  testWidgets('shows a search action and empty state', (tester) async {
    await tester.pumpWidget(buildSheet());

    expect(find.text('书签 (0)'), findsOneWidget);
    expect(find.byTooltip('搜索'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    final searchButton = find.byTooltip('搜索');
    expect(tester.getSize(searchButton).height, greaterThanOrEqualTo(48));
    await tester.tap(searchButton);
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('filters bookmark entries from the search field', (tester) async {
    Bookmark makeBookmark(String id, String title) => Bookmark(
      id: id,
      bookId: 'book-1',
      chapterIndex: 1,
      charOffset: 1,
      locatorJson: '{}',
      title: title,
      createdAt: DateTime(2026, 8, 3, 10, 30),
    );

    await tester.pumpWidget(
      buildSheet(
        bookmarks: [
          makeBookmark('bookmark-1', '第一章'),
          makeBookmark('bookmark-2', '第二章'),
        ],
      ),
    );

    await tester.tap(find.byTooltip('搜索'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '第二');
    await tester.pump();

    expect(find.text('第二章'), findsOneWidget);
    expect(find.text('第一章'), findsNothing);
  });

  testWidgets('keeps the search action visible at large text sizes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildSheet(textScaleFactor: 2));

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('搜索'), findsOneWidget);
  });

  testWidgets('shows bookmark entries with visible select and delete actions', (
    tester,
  ) async {
    final bookmark = Bookmark(
      id: 'bookmark-1',
      bookId: 'book-1',
      chapterIndex: 2,
      charOffset: 24,
      locatorJson: '{}',
      title: '第二章',
      createdAt: DateTime(2026, 8, 3, 10, 30),
    );
    Bookmark? selected;
    Bookmark? deleted;

    await tester.pumpWidget(
      buildSheet(
        bookmarks: [bookmark],
        onSelect: (entry) => selected = entry,
        onDelete: (entry) async => deleted = entry,
      ),
    );

    expect(find.text('书签 (1)'), findsOneWidget);
    expect(find.text('第二章'), findsOneWidget);
    expect(find.byTooltip('删除书签'), findsOneWidget);

    await tester.tap(find.text('第二章'));
    await tester.tap(find.byTooltip('删除书签'));
    await tester.pump();

    expect(selected, bookmark);
    expect(deleted, bookmark);
  });
}
