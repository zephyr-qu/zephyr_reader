import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr_reader/core/local/shared_preferences_service.dart';
import 'package:zephyr_reader/core/reading/config/reader_config.dart';
import 'package:zephyr_reader/features/reader/settings/display_panel.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

void main() {
  testWidgets('theme selection updates its highlight immediately', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final config = ReaderConfig(SharedPreferencesService(prefs));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DisplayPanel(config: config, onChanged: () {}),
        ),
      ),
    );

    BoxDecoration selectedDecoration(String label) {
      final finder = find.ancestor(
        of: find.text(label),
        matching: find.byType(AnimatedContainer),
      );
      return tester.widget<AnimatedContainer>(finder.first).decoration!
          as BoxDecoration;
    }

    expect(selectedDecoration('白天').border!.top.width, 1.5);
    expect(selectedDecoration('夜间').border!.top.width, 0.5);

    await tester.tap(find.text('夜间'));
    await tester.pump();

    expect(config.theme.value, ReaderTheme.dark);
    expect(selectedDecoration('白天').border!.top.width, 0.5);
    expect(selectedDecoration('夜间').border!.top.width, 1.5);
    expect(find.text('深色和护眼主题使用固定背景'), findsOneWidget);

    final backgroundIndexBeforeDisabledTap = config.readerBgColorIndex.value;
    await tester.tap(find.byKey(const ValueKey('reader-bg-2')));
    await tester.pump();
    expect(config.readerBgColorIndex.value, backgroundIndexBeforeDisabledTap);

    await tester.tap(find.text('白天'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('reader-bg-2')));
    await tester.pump();
    expect(config.readerBgColorIndex.value, 2);

    config.dispose();
  });
}
