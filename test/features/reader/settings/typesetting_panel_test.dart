import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr_reader/core/local/shared_preferences_service.dart';
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
    final lineHeight = _MockPersistedSignal<double>();
    final textAlign = _MockPersistedSignal<ReaderTextAlign>();
    var selectedMode = ReadingMode.pagination;

    when(() => config.fontSize).thenReturn(fontSize);
    when(() => fontSize.value).thenReturn(100);
    when(() => config.padding).thenReturn(padding);
    when(() => padding.value).thenReturn(20);
    when(() => config.lineHeight).thenReturn(lineHeight);
    when(() => lineHeight.value).thenReturn(1.4);
    when(() => config.textAlign).thenReturn(textAlign);
    when(() => textAlign.value).thenReturn(ReaderTextAlign.auto);
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
    expect(find.text('行间距'), findsOneWidget);
    // 低频项已移除，移至设置页「排版与字体」
    expect(find.text('字间距'), findsNothing);
    expect(find.text('段间距'), findsNothing);
    expect(find.text('首行缩进'), findsNothing);
    expect(find.text('文本对齐'), findsOneWidget);
    expect(find.text('左对齐'), findsOneWidget);
    expect(find.text('两端对齐'), findsOneWidget);
    final scrollButton = find.ancestor(
      of: find.text('滚动'),
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(scrollButton).height, greaterThanOrEqualTo(48));

    await tester.tap(find.text('滚动'));
    await tester.pump();

    expect(selectedMode, ReadingMode.scroll);
  });

  testWidgets('text alignment selection updates ReaderConfig', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final config = ReaderConfig(SharedPreferencesService(prefs));
    addTearDown(config.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(extensions: [ReaderThemeExtension.light()]),
        home: Scaffold(
          body: TypesettingPanel(
            config: config,
            readingMode: ReadingMode.pagination,
            onReadingModeChanged: (_) {},
            onChanged: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('两端对齐'));
    await tester.pump();

    expect(config.textAlign.value, ReaderTextAlign.justify);
  });

  testWidgets('slider changes are rendered immediately', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final config = ReaderConfig(SharedPreferencesService(prefs));
    addTearDown(config.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(extensions: [ReaderThemeExtension.light()]),
        home: Scaffold(
          body: TypesettingPanel(
            config: config,
            readingMode: ReadingMode.pagination,
            onReadingModeChanged: (_) {},
            onChanged: () {},
          ),
        ),
      ),
    );

    await tester.drag(find.byType(Slider).first, const Offset(60, 0));
    await tester.pump();

    final displayedFontSize = '${config.fontSize.value.round()}%';
    expect(config.fontSize.value, greaterThan(100));
    expect(find.text(displayedFontSize), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 200));
  });
}
