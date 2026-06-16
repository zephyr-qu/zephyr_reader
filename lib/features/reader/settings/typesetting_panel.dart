import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/features/reader/domain/service/custom_font_service.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';
import 'package:zephyr_reader/features/reader/settings/settings_widgets.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

class TypesettingPanel extends StatelessWidget {
  final ReaderConfig config;
  final ReadingMode readingMode;
  final FontRepository fontRepo;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<double> onLineHeightChanged;
  final ValueChanged<double> onPageMarginChanged;
  final ValueChanged<ReadingMode> onReadingModeChanged;

  const TypesettingPanel({
    super.key,
    required this.config,
    required this.readingMode,
    required this.fontRepo,
    required this.onFontSizeChanged,
    required this.onLineHeightChanged,
    required this.onPageMarginChanged,
    required this.onReadingModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final readerTheme = Theme.of(context).extension<ReaderThemeExtension>()!;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        sectionHeader(
          icon: PhosphorIconsRegular.textT,
          title: l10n.typographySection,
          mutedColor: readerTheme.mutedColor,
        ),
        sliderTile(
          label: l10n.fontSize,
          value: config.fontSize.value,
          min: 12,
          max: 32,
          divisions: 20,
          display: '${config.fontSize.value.toStringAsFixed(0)}px',
          onChanged: onFontSizeChanged,
          readerTheme: readerTheme,
        ),
        sliderTile(
          label: l10n.lineHeight,
          value: config.lineHeight.value,
          min: 0.7,
          max: 3.0,
          divisions: 23,
          display: config.lineHeight.value.toStringAsFixed(1),
          onChanged: onLineHeightChanged,
          readerTheme: readerTheme,
        ),
        sliderTile(
          label: l10n.pageMargin,
          value: config.padding.value,
          min: 8,
          max: 40,
          divisions: 16,
          display: '${config.padding.value.toStringAsFixed(0)}px',
          onChanged: onPageMarginChanged,
          readerTheme: readerTheme,
        ),
        const SizedBox(height: 4),
        textAlignSelector(
          readerTheme: readerTheme,
          l10n: l10n,
          config: config,
        ),
        const SizedBox(height: 2),
        _fontSelectionTile(
          readerTheme,
          l10n,
          () => _showFontSheet(context, readerTheme, l10n),
        ),
        _readingModeSelectionTile(
          readerTheme,
          l10n,
          () => _showReadingModeSheet(context, readerTheme, l10n),
        ),
      ],
    );
  }

  String _readingModeLabel(AppLocalizations l10n) {
    return switch (readingMode) {
      ReadingMode.scroll => l10n.scrollMode,
      ReadingMode.pageTurn => l10n.pageTurnMode,
      ReadingMode.pagination => l10n.paginationMode,
      ReadingMode.bilingual => l10n.bilingualMode,
    };
  }

  Widget _fontSelectionTile(
    ReaderThemeExtension readerTheme,
    AppLocalizations l10n,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Icon(
              PhosphorIconsRegular.textT,
              size: 15,
              color: readerTheme.mutedColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.fontSelection,
                style: TextStyle(color: readerTheme.textColor, fontSize: 13),
              ),
            ),
            Text(
              fontRepo.currentFont.value?.displayName ?? '',
              style: TextStyle(color: readerTheme.mutedColor, fontSize: 11),
            ),
            const SizedBox(width: 4),
            Icon(
              PhosphorIconsRegular.caretRight,
              size: 14,
              color: readerTheme.mutedColor,
            ),
          ],
        ),
      ),
    );
  }

  void _showFontSheet(
    BuildContext context,
    ReaderThemeExtension readerTheme,
    AppLocalizations l10n,
  ) {
    final fonts = fontRepo.availableFonts.value;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.fontSelection,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: readerTheme.textColor,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: fonts.map((font) {
                  final isSelected = fontRepo.currentFont.value?.id == font.id;
                  return ListTile(
                    title: Text(
                      font.displayName,
                      style: TextStyle(color: readerTheme.textColor),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check, color: readerTheme.accentColor)
                        : null,
                    onTap: () {
                      fontRepo.setCurrentFont(font.id);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _readingModeSelectionTile(
    ReaderThemeExtension readerTheme,
    AppLocalizations l10n,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Icon(
              PhosphorIconsRegular.bookOpenText,
              size: 15,
              color: readerTheme.mutedColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.readingModeSection,
                style: TextStyle(color: readerTheme.textColor, fontSize: 13),
              ),
            ),
            Text(
              _readingModeLabel(l10n),
              style: TextStyle(color: readerTheme.mutedColor, fontSize: 11),
            ),
            const SizedBox(width: 4),
            Icon(
              PhosphorIconsRegular.caretRight,
              size: 14,
              color: readerTheme.mutedColor,
            ),
          ],
        ),
      ),
    );
  }

  void _showReadingModeSheet(
    BuildContext context,
    ReaderThemeExtension readerTheme,
    AppLocalizations l10n,
  ) {
    final accentColor = readerTheme.accentColor;
    final modes = [
      (ReadingMode.scroll, l10n.scrollMode, PhosphorIconsRegular.arrowsDownUp),
      (ReadingMode.pageTurn, l10n.pageTurnMode, PhosphorIconsRegular.book),
      (
        ReadingMode.pagination,
        l10n.paginationMode,
        PhosphorIconsFill.bookOpenText,
      ),
      (
        ReadingMode.bilingual,
        l10n.bilingualMode,
        PhosphorIconsRegular.translate,
      ),
    ];

    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.readingModeSection,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: readerTheme.textColor,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: modes.map((m) {
                  final isSelected = readingMode == m.$1;
                  return ListTile(
                    leading: Icon(m.$3, color: readerTheme.textColor),
                    title: Text(
                      m.$2,
                      style: TextStyle(color: readerTheme.textColor),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check, color: accentColor)
                        : null,
                    onTap: () {
                      onReadingModeChanged(m.$1);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
