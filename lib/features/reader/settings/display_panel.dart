import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/reading/config/reader_config.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';
import 'package:zephyr_reader/features/reader/settings/settings_widgets.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// Display settings panel (Readium MVP — theme, font, background).
class DisplayPanel extends StatelessWidget {
  final ReaderConfig config;
  final VoidCallback onChanged;

  const DisplayPanel({
    super.key,
    required this.config,
    required this.onChanged,
  });

  static const _fontFamilies = [
    ('System', 'System'),
    ('Serif', 'Serif'),
    ('Noto Serif SC', 'Noto Serif SC'),
  ];

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
        themeSelector(
          readerTheme: readerTheme,
          l10n: l10n,
          config: config,
          onChanged: onChanged,
        ),
        const SizedBox(height: 8),
        _fontFamilySelector(readerTheme, l10n),
        const SizedBox(height: 4),
        bgColorPicker(readerTheme: readerTheme, l10n: l10n, config: config),
      ],
    );
  }

  Widget _fontFamilySelector(
    ReaderThemeExtension readerTheme,
    AppLocalizations l10n,
  ) {
    final accentColor = readerTheme.accentColor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              'Font',
              style: TextStyle(color: readerTheme.textColor, fontSize: 13),
            ),
          ),
          Expanded(
            child: Row(
              children: _fontFamilies.map((f) {
                final isSelected = config.fontFamily.value == f.$1;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: GestureDetector(
                      onTap: () {
                        config.fontFamily.value = f.$1;
                        onChanged();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? accentColor.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected
                                ? accentColor
                                : readerTheme.mutedColor.withValues(alpha: 0.2),
                            width: isSelected ? 1.5 : 0.5,
                          ),
                        ),
                        child: Text(
                          f.$2,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected
                                ? accentColor
                                : readerTheme.textColor,
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
