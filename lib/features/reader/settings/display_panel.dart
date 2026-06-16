import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';
import 'package:zephyr_reader/features/reader/settings/settings_widgets.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

class DisplayPanel extends StatelessWidget {
  final ReaderConfig config;

  const DisplayPanel({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    final readerTheme = Theme.of(context).extension<ReaderThemeExtension>()!;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        sectionHeader(
          icon: PhosphorIconsRegular.palette,
          title: l10n.appearanceSection,
          mutedColor: readerTheme.mutedColor,
        ),
        sliderTile(
          label: l10n.brightness,
          value: 1 - config.brightnessOverlay.value,
          min: 0.3,
          max: 1.0,
          divisions: 14,
          display:
              '${((1 - config.brightnessOverlay.value) * 100).toStringAsFixed(0)}%',
          onChanged: (v) => config.brightnessOverlay.value = 1 - v,
          readerTheme: readerTheme,
        ),
        const SizedBox(height: 8),
        themeSelector(readerTheme: readerTheme, l10n: l10n, config: config),
        const SizedBox(height: 12),
        fontScaleTile(readerTheme: readerTheme, l10n: l10n, config: config),
        const SizedBox(height: 8),
        bgColorPicker(readerTheme: readerTheme, l10n: l10n, config: config),
      ],
    );
  }
}
