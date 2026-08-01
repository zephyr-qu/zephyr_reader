import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';
import 'package:zephyr_reader/features/reader/page/toolbar/reader_bottom_toolbar.dart';
import 'package:zephyr_reader/features/reader/page/toolbar/reader_toolbar.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

void main() {
  testWidgets('restores the reader toolbar layout and actions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var closeCount = 0;
    var catalogCount = 0;
    var typesettingCount = 0;
    var displayCount = 0;
    var assistCount = 0;
    final readerTheme = ReaderThemeExtension.light();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            children: [
              ReaderToolbar(
                title: '测试书籍',
                progress: '42%',
                readerTheme: readerTheme,
                onClose: () => closeCount += 1,
              ),
              const Spacer(),
              ReaderBottomToolbar(
                readerTheme: readerTheme,
                onShowCatalog: () => catalogCount += 1,
                onToggleTypesetting: () => typesettingCount += 1,
                onToggleDisplay: () => displayCount += 1,
                onToggleAssist: () => assistCount += 1,
                isTtsPlaying: false,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('测试书籍'), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);
    expect(find.text('章节列表'), findsOneWidget);
    expect(find.text('文字排版'), findsOneWidget);
    expect(find.text('外观主题'), findsOneWidget);
    expect(find.text('阅读辅助'), findsOneWidget);
    expect(find.text('上一个'), findsNothing);
    expect(find.text('下一个'), findsNothing);

    final backButton = find.byType(IconButton);
    expect(tester.getSize(backButton).height, greaterThanOrEqualTo(48));
    final catalogButton = find.ancestor(
      of: find.text('章节列表'),
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(catalogButton).height, greaterThanOrEqualTo(48));

    await tester.tap(backButton);
    await tester.tap(find.text('章节列表'));
    await tester.tap(find.text('文字排版'));
    await tester.tap(find.text('外观主题'));
    await tester.tap(find.text('阅读辅助'));
    await tester.pump();

    expect(closeCount, 1);
    expect(catalogCount, 1);
    expect(typesettingCount, 1);
    expect(displayCount, 1);
    expect(assistCount, 1);
  });
}
