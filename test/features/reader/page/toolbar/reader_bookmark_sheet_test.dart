import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';
import 'package:zephyr_reader/features/reader/page/toolbar/reader_bookmark_sheet.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/domain/bookmark/models.dart';

void main() {
  Widget buildSheet({
    List<Bookmark> bookmarks = const [],
    bool isCurrentPageBookmarked = false,
    double textScaleFactor = 1,
    Future<void> Function()? onToggleCurrent,
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
          child: ReaderBookmarkSheet(
            bookmarks: bookmarks,
            readerTheme: ReaderThemeExtension.light(),
            isCurrentPageBookmarked: isCurrentPageBookmarked,
            onToggleCurrent: onToggleCurrent ?? () async {},
            onSelect: onSelect ?? (_) {},
            onDelete: onDelete ?? (_) async {},
          ),
        ),
      ),
    );
  }

  testWidgets('shows an explicit add action and empty state', (tester) async {
    var toggleCount = 0;
    await tester.pumpWidget(
      buildSheet(onToggleCurrent: () async => toggleCount += 1),
    );

    expect(find.text('书签 (0)'), findsOneWidget);
    expect(find.text('添加书签'), findsNWidgets(2));

    final addButton = find.byType(FilledButton);
    expect(tester.getSize(addButton).height, greaterThanOrEqualTo(48));
    await tester.tap(addButton);
    await tester.pump();

    expect(toggleCount, 1);
  });

  testWidgets('keeps the add action visible at large text sizes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildSheet(textScaleFactor: 2));

    expect(tester.takeException(), isNull);
    expect(find.byType(FilledButton), findsOneWidget);
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
        isCurrentPageBookmarked: true,
        onSelect: (entry) => selected = entry,
        onDelete: (entry) async => deleted = entry,
      ),
    );

    expect(find.text('书签 (1)'), findsOneWidget);
    expect(find.text('删除书签'), findsOneWidget);
    expect(find.text('第二章'), findsOneWidget);
    expect(find.byTooltip('删除书签'), findsOneWidget);

    await tester.tap(find.text('第二章'));
    await tester.tap(find.byTooltip('删除书签'));
    await tester.pump();

    expect(selected, bookmark);
    expect(deleted, bookmark);
  });
}
