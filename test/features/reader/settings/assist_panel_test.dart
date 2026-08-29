import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr_reader/core/local/shared_preferences_service.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';
import 'package:zephyr_reader/features/profile/application/tts_settings_view_model.dart';
import 'package:zephyr_reader/features/reader/settings/assist_panel.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

void main() {
  testWidgets('speed slider drag updates the TTS speed signal', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final ttsVm = TtsSettingsViewModel(SharedPreferencesService(prefs));
    addTearDown(ttsVm.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(extensions: [ReaderThemeExtension.light()]),
        home: Scaffold(
          body: AssistPanel(
            ttsVm: ttsVm,
            isTtsPlaying: false,
            onTtsToggle: () {},
            onPreferencesChanged: () {},
          ),
        ),
      ),
    );

    await tester.pump();
    expect(ttsVm.speed.value, 1.0);

    // 从滑块中点向右拖动，速度应提高。
    await tester.drag(find.byType(Slider).first, const Offset(80, 0));
    await tester.pump();

    expect(ttsVm.speed.value, greaterThan(1.0));

    await tester.pump(const Duration(milliseconds: 200));
  });
}
