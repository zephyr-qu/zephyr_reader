import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/reading/config/reader_config.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';
import 'package:zephyr_reader/features/reader/settings/settings_widgets.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// Display settings panel (Readium MVP — theme + font size only).
class DisplayPanel extends StatelessWidget {
  final ReaderConfig config;
  final VoidCallback onChanged;

  const DisplayPanel({
    super.key,
    required this.config,
    required this.onChanged,
  });

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
          label: l10n.fontSize,
          value: config.fontSize.value,
          min: 80,
          max: 200,
          divisions: 24,
          display: '${config.fontSize.value.round()}',
          onChanged: (v) {
            config.fontSize.value = v;
            onChanged();
          },
          readerTheme: readerTheme,
        ),
        const SizedBox(height: 8),
        themeSelector(
          readerTheme: readerTheme,
          l10n: l10n,
          config: config,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
