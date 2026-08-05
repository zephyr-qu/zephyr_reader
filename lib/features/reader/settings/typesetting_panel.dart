import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/reading/config/reader_config.dart';
import 'package:zephyr_reader/core/reading/config/reader_typography_defaults.dart';
import 'package:zephyr_reader/core/theme/anim_tokens.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';
import 'package:zephyr_reader/features/reader/settings/settings_widgets.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// Exposes the typography preferences supported by the Readium bridge.
/// Publisher-owned layout controls remain intentionally out of this panel.
/// 仅保留常用项（字号/页边距/行高/文本对齐/阅读模式）；
/// 字间距/段间距/首行缩进等低频项在设置页「排版与字体」中提供。
class TypesettingPanel extends StatefulWidget {
  final ReaderConfig config;
  final ReadingMode readingMode;
  final ValueChanged<ReadingMode> onReadingModeChanged;
  final VoidCallback onChanged;

  const TypesettingPanel({
    super.key,
    required this.config,
    required this.readingMode,
    required this.onReadingModeChanged,
    required this.onChanged,
  });

  @override
  State<TypesettingPanel> createState() => _TypesettingPanelState();
}

class _TypesettingPanelState extends State<TypesettingPanel> {
  late ReadingMode _readingMode;

  @override
  void initState() {
    super.initState();
    _readingMode = widget.readingMode;
  }

  @override
  void didUpdateWidget(TypesettingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.readingMode != widget.readingMode) {
      _readingMode = widget.readingMode;
    }
  }

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
          value: widget.config.fontSize.value,
          min: 80,
          max: 200,
          divisions: 24,
          display: '${widget.config.fontSize.value.round()}%',
          onChanged: (value) {
            widget.config.fontSize.value = value;
            widget.onChanged();
          },
          readerTheme: readerTheme,
        ),
        sliderTile(
          label: l10n.pageMargin,
          value: widget.config.padding.value,
          min: ReaderTypographyDefaults.minPadding,
          max: ReaderTypographyDefaults.maxPadding,
          divisions: 16,
          display: '${widget.config.padding.value.round()}',
          onChanged: (value) {
            widget.config.padding.value = value;
            widget.onChanged();
          },
          readerTheme: readerTheme,
        ),
        sliderTile(
          label: l10n.lineHeight,
          value: widget.config.lineHeight.value,
          min: 1.0,
          max: 2.0,
          divisions: 10,
          display: '${widget.config.lineHeight.value.toStringAsFixed(1)}x',
          onChanged: (value) {
            widget.config.lineHeight.value = value;
            widget.onChanged();
          },
          readerTheme: readerTheme,
        ),
        const SizedBox(height: 4),
        _buildTextAlignmentSelector(readerTheme, l10n),
        const SizedBox(height: 4),
        _buildReadingModeSelector(readerTheme, l10n),
      ],
    );
  }

  Widget _buildTextAlignmentSelector(
    ReaderThemeExtension readerTheme,
    AppLocalizations l10n,
  ) {
    final options = [
      (ReaderTextAlign.auto, l10n.textAlignAuto, PhosphorIconsRegular.textAa),
      (
        ReaderTextAlign.left,
        l10n.textAlignLeft,
        PhosphorIconsRegular.textAlignLeft,
      ),
      (
        ReaderTextAlign.justify,
        l10n.textAlignJustify,
        PhosphorIconsRegular.textAlignJustify,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              l10n.textAlignment,
              style: TextStyle(color: readerTheme.textColor, fontSize: 13),
            ),
          ),
          Expanded(
            child: Row(
              children: options.map((option) {
                final isSelected = widget.config.textAlign.value == option.$1;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Semantics(
                      button: true,
                      selected: isSelected,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () {
                            if (isSelected) return;
                            widget.config.textAlign.value = option.$1;
                            widget.onChanged();
                          },
                          child: AnimatedContainer(
                            duration: AnimTokens.medium,
                            constraints: const BoxConstraints(minHeight: 48),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? readerTheme.accentColor.withValues(
                                      alpha: 0.1,
                                    )
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected
                                    ? readerTheme.accentColor
                                    : readerTheme.mutedColor.withValues(
                                        alpha: 0.2,
                                      ),
                                width: isSelected ? 1.5 : 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  option.$3,
                                  size: 16,
                                  color: isSelected
                                      ? readerTheme.accentColor
                                      : readerTheme.mutedColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  option.$2,
                                  style: TextStyle(
                                    color: isSelected
                                        ? readerTheme.accentColor
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
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _buildReadingModeSelector(
    ReaderThemeExtension readerTheme,
    AppLocalizations l10n,
  ) {
    final options = [
      (
        ReadingMode.pagination,
        l10n.paginationMode,
        PhosphorIconsRegular.bookOpenText,
      ),
      (ReadingMode.scroll, l10n.scrollMode, PhosphorIconsRegular.arrowsDownUp),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              l10n.readingModeSection,
              style: TextStyle(color: readerTheme.textColor, fontSize: 13),
            ),
          ),
          Expanded(
            child: Row(
              children: options.map((option) {
                final isSelected = _readingMode == option.$1;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Semantics(
                      button: true,
                      selected: isSelected,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () {
                            if (isSelected) return;
                            setState(() => _readingMode = option.$1);
                            widget.onReadingModeChanged(option.$1);
                          },
                          child: AnimatedContainer(
                            duration: AnimTokens.medium,
                            constraints: const BoxConstraints(minHeight: 48),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? readerTheme.accentColor.withValues(
                                      alpha: 0.1,
                                    )
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected
                                    ? readerTheme.accentColor
                                    : readerTheme.mutedColor.withValues(
                                        alpha: 0.2,
                                      ),
                                width: isSelected ? 1.5 : 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  option.$3,
                                  size: 16,
                                  color: isSelected
                                      ? readerTheme.accentColor
                                      : readerTheme.mutedColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  option.$2,
                                  style: TextStyle(
                                    color: isSelected
                                        ? readerTheme.accentColor
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
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }
}
