import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/reading/config/reader_config.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';
import 'package:zephyr_reader/features/profile/application/tts_settings_view_model.dart';
import 'package:zephyr_reader/features/reader/settings/settings_widgets.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

class AssistPanel extends StatelessWidget {
  final ReaderConfig config;
  final TtsSettingsViewModel ttsVm;
  final bool isTtsPlaying;
  final bool isTtsPaused;
  final VoidCallback onTtsToggle;

  const AssistPanel({
    super.key,
    required this.config,
    required this.ttsVm,
    required this.isTtsPlaying,
    required this.isTtsPaused,
    required this.onTtsToggle,
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
          isTtsPaused: isTtsPaused,
          onTtsToggle: onTtsToggle,
        ),
        _ttsSpeedSlider(readerTheme, l10n),
        _ttsAutoPageTile(readerTheme, l10n),
        _ttsOriginalOnlyTile(readerTheme, l10n),
        autoScrollTile(readerTheme: readerTheme, l10n: l10n, config: config),
        sliderTile(
          label: l10n.autoScrollSpeed,
          value: config.autoScrollSpeed.value.toDouble(),
          min: 10,
          max: 120,
          divisions: 22,
          display: '${config.autoScrollSpeed.value}s',
          onChanged: (v) => config.autoScrollSpeed.value = v.round(),
          readerTheme: readerTheme,
          enabled: config.autoScroll.value,
        ),
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
      onChanged: (v) => ttsVm.speed.value = v,
      readerTheme: readerTheme,
    );
  }

  Widget _ttsAutoPageTile(
    ReaderThemeExtension readerTheme,
    AppLocalizations l10n,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(
            PhosphorIconsRegular.arrowSquareRight,
            size: 15,
            color: readerTheme.mutedColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.ttsAutoPage,
              style: TextStyle(color: readerTheme.textColor, fontSize: 13),
            ),
          ),
          Switch(
            value: ttsVm.autoPage.value,
            onChanged: (v) => ttsVm.autoPage.value = v,
            activeThumbColor: readerTheme.accentColor,
          ),
        ],
      ),
    );
  }

  Widget _ttsOriginalOnlyTile(
    ReaderThemeExtension readerTheme,
    AppLocalizations l10n,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(
            PhosphorIconsRegular.translate,
            size: 15,
            color: readerTheme.mutedColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.ttsOriginalOnly,
              style: TextStyle(color: readerTheme.textColor, fontSize: 13),
            ),
          ),
          Switch(
            value: ttsVm.originalOnly.value,
            onChanged: (v) => ttsVm.originalOnly.value = v,
            activeThumbColor: readerTheme.accentColor,
          ),
        ],
      ),
    );
  }
}
