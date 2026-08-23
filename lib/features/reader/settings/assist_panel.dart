import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';
import 'package:zephyr_reader/features/profile/application/tts_settings_view_model.dart';
import 'package:zephyr_reader/features/reader/settings/settings_widgets.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

class AssistPanel extends StatelessWidget {
  final TtsSettingsViewModel ttsVm;
  final bool isTtsPlaying;
  final VoidCallback onTtsToggle;
  final VoidCallback onPreferencesChanged;

  const AssistPanel({
    super.key,
    required this.ttsVm,
    required this.isTtsPlaying,
    required this.onTtsToggle,
    required this.onPreferencesChanged,
  });

  @override
  Widget build(BuildContext context) {
    final readerTheme = Theme.of(context).extension<ReaderThemeExtension>()!;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        sectionHeader(
          icon: PhosphorIconsRegular.waveform,
          title: l10n.readingAssist,
          mutedColor: readerTheme.mutedColor,
        ),
        ttsTile(
          readerTheme: readerTheme,
          l10n: l10n,
          isTtsPlaying: isTtsPlaying,
          onTtsToggle: onTtsToggle,
        ),
        _ttsSpeedSlider(readerTheme, l10n),
      ],
    );
  }

  Widget _ttsSpeedSlider(
    ReaderThemeExtension readerTheme,
    AppLocalizations l10n,
  ) {
    return sliderTile(
      label: l10n.ttsSpeed,
      value: ttsVm.speed.value,
      min: 0.5,
      max: 2.0,
      divisions: 15,
      display: '${ttsVm.speed.value.toStringAsFixed(1)}x',
      onChanged: (v) {
        ttsVm.speed.value = v;
        onPreferencesChanged();
      },
      readerTheme: readerTheme,
    );
  }
}
