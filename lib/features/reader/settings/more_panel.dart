import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/reader_engine/shared/config/reader_config.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';
import 'package:zephyr_reader/features/reader/settings/settings_widgets.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

class MorePanel extends StatelessWidget {
  final ReaderConfig config;

  const MorePanel({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    final readerTheme = Theme.of(context).extension<ReaderThemeExtension>()!;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        sectionHeader(
          icon: PhosphorIconsRegular.handTap,
          title: l10n.tapLayout,
          mutedColor: readerTheme.mutedColor,
        ),
        tapLayoutToggle(readerTheme: readerTheme, l10n: l10n, config: config),
      ],
    );
  }
}
