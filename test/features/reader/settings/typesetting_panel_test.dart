import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zephyr_reader/core/reading/config/reader_config.dart';
import 'package:zephyr_reader/core/settings/persisted_signal.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';
import 'package:zephyr_reader/features/reader/settings/typesetting_panel.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

class _MockReaderConfig extends Mock implements ReaderConfig {}

class _MockPersistedSignal<T> extends Mock implements PersistedSignal<T> {}

void main() {
  testWidgets('shows and changes the Readium reading mode', (tester) async {
    final config = _MockReaderConfig();
    final fontSize = _MockPersistedSignal<double>();
    final padding = _MockPersistedSignal<double>();
    var selectedMode = ReadingMode.pagination;

    when(() => config.fontSize).thenReturn(fontSize);
    when(() => fontSize.value).thenReturn(100);
    when(() => config.padding).thenReturn(padding);
    when(() => padding.value).thenReturn(20);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(extensions: [ReaderThemeExtension.light()]),
        home: Scaffold(
          body: TypesettingPanel(
            config: config,
            readingMode: selectedMode,
            onReadingModeChanged: (mode) => selectedMode = mode,
            onChanged: () {},
          ),
        ),
      ),
    );

    expect(find.text('阅读模式'), findsOneWidget);
    expect(find.text('分页'), findsOneWidget);
    expect(find.text('滚动'), findsOneWidget);

    final scrollButton = find.ancestor(
      of: find.text('滚动'),
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(scrollButton).height, greaterThanOrEqualTo(48));

    await tester.tap(find.text('滚动'));
    await tester.pump();

    expect(selectedMode, ReadingMode.scroll);
  });
}
