import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

class ReaderSettingsPanel extends HookWidget {
  final ThemeMode themeMode;
  final ReadingMode readingMode;
  final double fontSize;
  final double lineHeight;
  final double letterSpacing;
  final double paragraphSpacing;
  final double pageMargin;
  final WritingDirection writingDirection;

  final ValueChanged<ReadingMode> onReadingModeChanged;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<double> onLineHeightChanged;
  final ValueChanged<ThemeMode> onThemeChanged;
  final ValueChanged<double> onLetterSpacingChanged;
  final ValueChanged<double> onParagraphSpacingChanged;
  final ValueChanged<double> onPageMarginChanged;
  final ValueChanged<WritingDirection> onWritingDirectionChanged;
  final int readerBgColorIndex;
  final ValueChanged<int> onReaderBgColorChanged;
  final double brightnessValue;
  final ValueChanged<double> onBrightnessChanged;
  final TapLayout tapLayout;
  final ValueChanged<TapLayout> onTapLayoutChanged;
  final bool followSystemFontScale;
  final ValueChanged<bool> onFollowSystemFontScale;
  final VoidCallback onClose;

  const ReaderSettingsPanel({
    super.key,
    required this.themeMode,
    required this.readingMode,
    required this.fontSize,
    required this.lineHeight,
    required this.letterSpacing,
    required this.paragraphSpacing,
    required this.pageMargin,
    required this.writingDirection,
    required this.onReadingModeChanged,
    required this.onFontSizeChanged,
    required this.onLineHeightChanged,
    required this.onThemeChanged,
    required this.onLetterSpacingChanged,
    required this.onParagraphSpacingChanged,
    required this.onPageMarginChanged,
    required this.onWritingDirectionChanged,
    required this.readerBgColorIndex,
    required this.onReaderBgColorChanged,
    required this.tapLayout,
    required this.onTapLayoutChanged,
    required this.followSystemFontScale,
    required this.onFollowSystemFontScale,
    required this.brightnessValue,
    required this.onBrightnessChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final readerTheme = Theme.of(context).extension<ReaderThemeExtension>()!;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      color: readerTheme.backgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(readerTheme),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  _buildSectionHeader(
                    icon: PhosphorIconsRegular.palette,
                    title: l10n.appearanceSection,
                    mutedColor: readerTheme.mutedColor,
                  ),
                  _buildSliderTile(
                    label: l10n.brightness,
                    value: 1 - brightnessValue,
                    min: 0.3,
                    max: 1.0,
                    divisions: 14,
                    display:
                        '${((1 - brightnessValue) * 100).toStringAsFixed(0)}%',
                    onChanged: (v) => onBrightnessChanged(1 - v),
                    readerTheme: readerTheme,
                  ),
                  const SizedBox(height: 4),
                  _buildThemeSelector(readerTheme, l10n),
                  const SizedBox(height: 8),
                  _buildFontScaleToggle(readerTheme, l10n),
                  const SizedBox(height: 4),
                  _buildBgColorPicker(readerTheme, l10n),
                  const SizedBox(height: 8),
                  _buildTapLayoutToggle(readerTheme, l10n),
                  const Divider(height: 20, indent: 16, endIndent: 16),
                  _buildSectionHeader(
                    icon: PhosphorIconsRegular.bookOpenText,
                    title: l10n.readingModeSection,
                    mutedColor: readerTheme.mutedColor,
                  ),
                  _buildModeSelector(readerTheme, l10n),
                  const Divider(height: 20, indent: 16, endIndent: 16),
                  _buildSectionHeader(
                    icon: PhosphorIconsRegular.paragraph,
                    title: l10n.layoutSection,
                    mutedColor: readerTheme.mutedColor,
                  ),
                  _buildWritingDirectionSelector(readerTheme, l10n),
                  _buildSliderTile(
                    label: l10n.letterSpacing,
                    value: letterSpacing,
                    min: 0,
                    max: 8,
                    divisions: 16,
                    display: letterSpacing.toStringAsFixed(1),
                    onChanged: onLetterSpacingChanged,
                    readerTheme: readerTheme,
                  ),
                  _buildSliderTile(
                    label: l10n.paragraphSpacing,
                    value: paragraphSpacing,
                    min: 4,
                    max: 32,
                    divisions: 14,
                    display: paragraphSpacing.toStringAsFixed(0),
                    onChanged: onParagraphSpacingChanged,
                    readerTheme: readerTheme,
                  ),
                  _buildSliderTile(
                    label: l10n.pageMargin,
                    value: pageMargin,
                    min: 8,
                    max: 40,
                    divisions: 16,
                    display: '${pageMargin.toStringAsFixed(0)}px',
                    onChanged: onPageMarginChanged,
                    readerTheme: readerTheme,
                  ),
                  const Divider(height: 20, indent: 16, endIndent: 16),
                  _buildSectionHeader(
                    icon: PhosphorIconsRegular.textT,
                    title: l10n.typographySection,
                    mutedColor: readerTheme.mutedColor,
                  ),
                  _buildSliderTile(
                    label: l10n.fontSize,
                    value: fontSize,
                    min: 12,
                    max: 32,
                    divisions: 20,
                    display: '${fontSize.toStringAsFixed(0)}px',
                    onChanged: onFontSizeChanged,
                    readerTheme: readerTheme,
                  ),
                  _buildSliderTile(
                    label: l10n.lineHeight,
                    value: lineHeight,
                    min: 1.0,
                    max: 3.0,
                    divisions: 20,
                    display: lineHeight.toStringAsFixed(1),
                    onChanged: onLineHeightChanged,
                    readerTheme: readerTheme,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ReaderThemeExtension readerTheme) {
    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
          onClose();
        }
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: readerTheme.mutedColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color mutedColor,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
      child: Row(
        children: [
          Icon(icon, size: 15, color: mutedColor),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              color: mutedColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector(
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: modes.map((m) {
          final isSelected = readingMode == m.$1;
          return GestureDetector(
            onTap: () => onReadingModeChanged(m.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    m.$3,
                    size: 14,
                    color: isSelected ? accentColor : readerTheme.mutedColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    m.$2,
                    style: TextStyle(
                      color: isSelected ? accentColor : readerTheme.textColor,
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWritingDirectionSelector(
    ReaderThemeExtension readerTheme,
    AppLocalizations l10n,
  ) {
    final accentColor = readerTheme.accentColor;
    final directions = [
      (
        WritingDirection.horizontal,
        l10n.horizontal,
        PhosphorIconsRegular.textT,
      ),
      (WritingDirection.vertical, l10n.vertical, PhosphorIconsRegular.textAa),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: directions.map((d) {
          final isSelected = writingDirection == d.$1;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: GestureDetector(
                onTap: () => onWritingDirectionChanged(d.$1),
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        d.$3,
                        size: 14,
                        color: isSelected
                            ? accentColor
                            : readerTheme.mutedColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        d.$2,
                        style: TextStyle(
                          color: isSelected
                              ? accentColor
                              : readerTheme.textColor,
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildThemeSelector(
    ReaderThemeExtension readerTheme,
    AppLocalizations l10n,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: _buildChip(
              label: l10n.themeLight,
              icon: PhosphorIconsRegular.sun,
              selected: themeMode == ThemeMode.light,
              readerTheme: readerTheme,
              onTap: () => onThemeChanged(ThemeMode.light),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildChip(
              label: l10n.themeDark,
              icon: PhosphorIconsRegular.moon,
              selected: themeMode == ThemeMode.dark,
              readerTheme: readerTheme,
              onTap: () => onThemeChanged(ThemeMode.dark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required IconData icon,
    required bool selected,
    required ReaderThemeExtension readerTheme,
    required VoidCallback onTap,
  }) {
    final accentColor = readerTheme.accentColor;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? accentColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? accentColor
                : readerTheme.mutedColor.withValues(alpha: 0.2),
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? accentColor : readerTheme.mutedColor,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? accentColor : readerTheme.textColor,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBgColorPicker(
    ReaderThemeExtension readerTheme,
    AppLocalizations l10n,
  ) {
    final accentColor = readerTheme.accentColor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.readerBgColor,
            style: TextStyle(
              color: readerTheme.mutedColor,
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(ReaderBgColors.presets.length, (i) {
              final isDark = ReaderBgColors.presets[i].computeLuminance() < 0.5;
              return GestureDetector(
                onTap: () => onReaderBgColorChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: ReaderBgColors.presets[i],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: readerBgColorIndex == i
                          ? accentColor
                          : readerTheme.mutedColor.withValues(alpha: 0.15),
                      width: readerBgColorIndex == i ? 2.5 : 1,
                    ),
                    boxShadow: readerBgColorIndex == i
                        ? [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.2),
                              blurRadius: 4,
                              spreadRadius: 0,
                            ),
                          ]
                        : null,
                  ),
                  child: readerBgColorIndex == i
                      ? Icon(
                          PhosphorIconsBold.check,
                          size: 16,
                          color: isDark ? Colors.white : Colors.black54,
                        )
                      : null,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTapLayoutToggle(
    ReaderThemeExtension readerTheme,
    AppLocalizations l10n,
  ) {
    final accentColor = readerTheme.accentColor;
    final options = [
      (
        TapLayout.rightHanded,
        l10n.tapLayoutRightHanded,
        PhosphorIconsRegular.handPointing,
      ),
      (
        TapLayout.leftHanded,
        l10n.tapLayoutLeftHanded,
        PhosphorIconsRegular.handFist,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.tapLayout,
            style: TextStyle(
              color: readerTheme.mutedColor,
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: options.map((opt) {
              final isSelected = tapLayout == opt.$1;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: GestureDetector(
                    onTap: () => onTapLayoutChanged(opt.$1),
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            opt.$3,
                            size: 14,
                            color: isSelected
                                ? accentColor
                                : readerTheme.mutedColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            opt.$2,
                            style: TextStyle(
                              color: isSelected
                                  ? accentColor
                                  : readerTheme.textColor,
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderTile({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String display,
    required ValueChanged<double> onChanged,
    required ReaderThemeExtension readerTheme,
    Widget? preview,
  }) {
    final accentColor = readerTheme.accentColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: readerTheme.textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  display,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: accentColor,
              inactiveTrackColor: readerTheme.mutedColor.withValues(
                alpha: 0.12,
              ),
              thumbColor: accentColor,
              overlayColor: accentColor.withValues(alpha: 0.08),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          if (preview != null)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 2),
              child: preview,
            ),
        ],
      ),
    );
  }

  Widget _buildFontScaleToggle(
    ReaderThemeExtension readerTheme,
    AppLocalizations l10n,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          Text(
            l10n.followSystemFontScale,
            style: TextStyle(
              color: readerTheme.mutedColor,
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 24,
            child: Switch.adaptive(
              value: followSystemFontScale,
              onChanged: onFollowSystemFontScale,
            ),
          ),
        ],
      ),
    );
  }
}
