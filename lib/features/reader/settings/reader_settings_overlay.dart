import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/reading/config/reader_config.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';
import 'package:zephyr_reader/features/profile/application/tts_settings_view_model.dart';
import 'package:zephyr_reader/features/reader/settings/assist_panel.dart';
import 'package:zephyr_reader/features/reader/settings/display_panel.dart';
import 'package:zephyr_reader/features/reader/settings/reader_panel_type.dart';
import 'package:zephyr_reader/features/reader/settings/settings_widgets.dart';
import 'package:zephyr_reader/features/reader/settings/typesetting_panel.dart';

/// Reader settings bottom sheet (adapted for Readium MVP).
class ReaderSettingsOverlay extends StatelessWidget {
  final ReaderPanelType panelType;
  final ReaderConfig config;
  final ReadingMode readingMode;
  final ValueChanged<ReadingMode> onReadingModeChanged;
  final bool isTtsPlaying;
  final VoidCallback onTtsToggle;
  final VoidCallback onClose;
  final VoidCallback onPreferencesChanged;
  final TtsSettingsViewModel ttsVm;

  const ReaderSettingsOverlay({
    super.key,
    required this.panelType,
    required this.config,
    required this.readingMode,
    required this.onReadingModeChanged,
    required this.isTtsPlaying,
    required this.onTtsToggle,
    required this.onClose,
    required this.ttsVm,
    required this.onPreferencesChanged,
  });

  @override
  Widget build(BuildContext context) {
    final readerTheme = Theme.of(context).extension<ReaderThemeExtension>()!;

    return Container(
      decoration: BoxDecoration(
        color: readerTheme.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            buildHandle(theme: readerTheme, onClose: onClose),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  switch (panelType) {
                    ReaderPanelType.typesetting => TypesettingPanel(
                      config: config,
                      readingMode: readingMode,
                      onReadingModeChanged: onReadingModeChanged,
                      onChanged: onPreferencesChanged,
                    ),
                    ReaderPanelType.display => DisplayPanel(
                      config: config,
                      onChanged: onPreferencesChanged,
                    ),
                    ReaderPanelType.assist => AssistPanel(
                      config: config,
                      ttsVm: ttsVm,
                      isTtsPlaying: isTtsPlaying,
                      onTtsToggle: onTtsToggle,
                      onPreferencesChanged: onPreferencesChanged,
                    ),
                  },
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
