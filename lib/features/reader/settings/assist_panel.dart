import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';
import 'package:zephyr_reader/features/profile/application/tts_settings_view_model.dart';
import 'package:zephyr_reader/features/reader/settings/settings_widgets.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

class AssistPanel extends HookWidget {
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
    final double speed = useSignalValue<double, ReadonlySignal<double>>(ttsVm.speed.signal);
    final double pitch = useSignalValue<double, ReadonlySignal<double>>(ttsVm.pitch.signal);

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
        _ttsSpeedSlider(readerTheme, l10n, speed),
        _ttsPitchSlider(readerTheme, l10n, pitch),
      ],
    );
  }


  Widget _ttsSpeedSlider(
    ReaderThemeExtension readerTheme,
    AppLocalizations l10n,
    double speed,
  ) {
    return sliderTile(
      label: l10n.ttsSpeed,
      value: speed,
      min: 0.5,
      max: 2.0,
      divisions: 15,
      display: '${speed.toStringAsFixed(1)}x',
      onChanged: (v) {
        ttsVm.speed.value = v;
        onPreferencesChanged();
      },
      readerTheme: readerTheme,
    );
  }

  Widget _ttsPitchSlider(
    ReaderThemeExtension readerTheme,
    AppLocalizations l10n,
    double pitch,
  ) {
    return sliderTile(
      label: l10n.ttsPitch,
      value: pitch,
      min: 0.5,
      max: 2.0,
      divisions: 15,
      display: pitch.toStringAsFixed(1),
      onChanged: (v) {
        ttsVm.pitch.value = v;
        onPreferencesChanged();
      },
      readerTheme: readerTheme,
    );
  }
}
