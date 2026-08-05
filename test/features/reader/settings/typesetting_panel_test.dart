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
    final lineHeight = _MockPersistedSignal<double>();
    final letterSpacing = _MockPersistedSignal<double>();
    final paragraphSpacing = _MockPersistedSignal<double>();
    final paragraphIndent = _MockPersistedSignal<double>();
    final textAlign = _MockPersistedSignal<ReaderTextAlign>();
    var selectedMode = ReadingMode.pagination;

    when(() => config.fontSize).thenReturn(fontSize);
    when(() => fontSize.value).thenReturn(100);
    when(() => config.padding).thenReturn(padding);
    when(() => padding.value).thenReturn(20);
    when(() => config.lineHeight).thenReturn(lineHeight);
    when(() => lineHeight.value).thenReturn(1.4);
    when(() => config.letterSpacing).thenReturn(letterSpacing);
    when(() => letterSpacing.value).thenReturn(0.0);
    when(() => config.paragraphSpacing).thenReturn(paragraphSpacing);
    when(() => paragraphSpacing.value).thenReturn(0.0);
    when(() => config.paragraphIndent).thenReturn(paragraphIndent);
    when(() => paragraphIndent.value).thenReturn(0.0);
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
    expect(find.text('字间距'), findsOneWidget);
    expect(find.text('段间距'), findsOneWidget);
    expect(find.text('首行缩进'), findsOneWidget);
    expect(find.text('文本对齐'), findsOneWidget);
    // 对齐方式平铺展示，只保留 跟随原书 / 左对齐 / 两端对齐
    expect(find.text('跟随原书'), findsOneWidget);
    expect(find.text('左对齐'), findsOneWidget);
    expect(find.text('两端对齐'), findsOneWidget);
    expect(find.text('居中'), findsNothing);
    expect(find.text('右对齐'), findsNothing);

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
