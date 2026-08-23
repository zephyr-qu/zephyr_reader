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
/// 仅保留常用项（字号/页边距/行高/对齐方式/阅读模式）；
/// 字间距/段间距/首行缩进等低频项在设置页「排版与字体」中提供。
class TypesettingPanel extends StatefulWidget {
  final ReaderConfig config;
  final ReadingMode readingMode;
  final bool isScrollModeSupported;
  final ValueChanged<ReadingMode> onReadingModeChanged;
  final VoidCallback onChanged;

  const TypesettingPanel({
    super.key,
    required this.config,
    required this.readingMode,
    this.isScrollModeSupported = true,
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
    final fontSize = widget.config.fontSize.value
        .clamp(
          ReaderTypographyDefaults.minFontSize,
          ReaderTypographyDefaults.maxFontSize,
        )
        .toDouble();
    final padding = widget.config.padding.value
        .clamp(
          ReaderTypographyDefaults.minPadding,
          ReaderTypographyDefaults.maxPadding,
        )
        .toDouble();
    final lineHeight = widget.config.lineHeight.value
        .clamp(
          ReaderTypographyDefaults.minLineHeight,
          ReaderTypographyDefaults.maxLineHeight,
        )
        .toDouble();

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
          value: fontSize,
          min: ReaderTypographyDefaults.minFontSize,
          max: ReaderTypographyDefaults.maxFontSize,
          divisions: 20,
          display: '${fontSize.round()}%',
          onChanged: (value) {
            setState(() => widget.config.fontSize.value = value);
            widget.onChanged();
          },
          readerTheme: readerTheme,
        ),
        sliderTile(
          label: l10n.pageMargin,
          value: padding,
          min: ReaderTypographyDefaults.minPadding,
          max: ReaderTypographyDefaults.maxPadding,
          divisions: 12,
          display: '${padding.round()}',
          onChanged: (value) {
            setState(() => widget.config.padding.value = value);
            widget.onChanged();
          },
          readerTheme: readerTheme,
        ),
        sliderTile(
          label: l10n.lineHeight,
          value: lineHeight,
          min: ReaderTypographyDefaults.minLineHeight,
          max: ReaderTypographyDefaults.maxLineHeight,
          divisions: 8,
          display: '${lineHeight.toStringAsFixed(1)}x',
          onChanged: (value) {
            setState(() => widget.config.lineHeight.value = value);
            widget.onChanged();
          },
          readerTheme: readerTheme,
        ),
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
      (ReaderTextAlign.auto, l10n.textAlignAuto, Icons.format_align_left),
      (ReaderTextAlign.left, l10n.textAlignLeft, Icons.format_align_left),
      (
        ReaderTextAlign.justify,
        l10n.textAlignJustify,
        Icons.format_align_justify,
      ),
    ];
    final selected = widget.config.textAlign.value;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.textAlignment,
            style: TextStyle(color: readerTheme.textColor, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Row(
            children: options.map((option) {
              final isSelected = selected == option.$1;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Semantics(
                    button: true,
                    selected: isSelected,
                    label: option.$2,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () {
                          if (isSelected) return;
                          setState(
                            () => widget.config.textAlign.value = option.$1,
                          );
                          widget.onChanged();
                        },
                        child: AnimatedContainer(
                          duration: AnimTokens.medium,
                          constraints: const BoxConstraints(minHeight: 48),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? readerTheme.accentColor.withValues(alpha: 0.1)
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
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                option.$3,
                                size: 16,
                                color: isSelected
                                    ? readerTheme.accentColor
                                    : readerTheme.mutedColor,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                option.$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isSelected
                                      ? readerTheme.accentColor
                                      : readerTheme.textColor,
                                  fontSize: 10,
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
                final isEnabled =
                    option.$1 != ReadingMode.scroll ||
                    widget.isScrollModeSupported;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Semantics(
                      button: true,
                      enabled: isEnabled,
                      selected: isSelected,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () {
                            if (isSelected || !isEnabled) return;
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
                                      : !isEnabled
                                      ? readerTheme.mutedColor.withValues(
                                          alpha: 0.45,
                                        )
                                      : readerTheme.mutedColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  option.$2,
                                  style: TextStyle(
                                    color: isSelected
                                        ? readerTheme.accentColor
                                        : !isEnabled
                                        ? readerTheme.mutedColor.withValues(
                                            alpha: 0.45,
                                          )
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
