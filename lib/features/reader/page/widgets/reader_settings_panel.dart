library;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:zephyr_reader/core/theme/theme_constants.dart';
import '../../application/reader_view_model.dart';

class ReaderSettingsPanel extends StatefulWidget {
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
    required this.brightnessValue,
    required this.onBrightnessChanged,
    required this.onClose,
  });

  @override
  State<ReaderSettingsPanel> createState() => _ReaderSettingsPanelState();
}

class _ReaderSettingsPanelState extends State<ReaderSettingsPanel> {
  static const _bgColors = [
    Color(0xFFFAFAFA),
    Color(0xFFF5F0E8),
    Color(0xFFFFF8E7),
    Color(0xFFC7EDCC),
    Color(0xFFF0F0F0),
  ];

  Color get _textColor => widget.themeMode == ThemeMode.dark
      ? const Color(0xFFE8E6E1)
      : const Color(0xFF2C2C2C);

  Color get _mutedColor => widget.themeMode == ThemeMode.dark
      ? const Color(0xFF6B6B76)
      : const Color(0xFF9C9C9C);

  Color get _bgColor => widget.themeMode == ThemeMode.dark
      ? const Color(0xFF111118)
      : const Color(0xFFF8F6F0);

  @override
  Widget build(BuildContext context) {
    final accentColor = DesignTokens.warmAccent;

    return Container(
      color: _bgColor,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(accentColor),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  _buildSectionHeader(
                    icon: PhosphorIconsRegular.palette,
                    title: '外观主题',
                  ),
                  _buildSliderTile(
                    label: '亮度',
                    value: 1 - widget.brightnessValue,
                    min: 0.3,
                    max: 1.0,
                    divisions: 14,
                    display:
                        '${((1 - widget.brightnessValue) * 100).toStringAsFixed(0)}%',
                    onChanged: (v) => widget.onBrightnessChanged(1 - v),
                    accentColor: accentColor,
                  ),
                  const SizedBox(height: 4),
                  _buildThemeSelector(accentColor),
                  const SizedBox(height: 4),
                  _buildBgColorPicker(accentColor),
                  const Divider(height: 20, indent: 16, endIndent: 16),
                  _buildSectionHeader(
                    icon: PhosphorIconsRegular.bookOpenText,
                    title: '阅读模式',
                  ),
                  _buildModeSelector(accentColor),
                  const Divider(height: 20, indent: 16, endIndent: 16),
                  _buildSectionHeader(
                    icon: PhosphorIconsRegular.paragraph,
                    title: '版面布局',
                  ),
                  _buildWritingDirectionSelector(accentColor),
                  _buildSliderTile(
                    label: '字间距',
                    value: widget.letterSpacing,
                    min: 0,
                    max: 8,
                    divisions: 16,
                    display: widget.letterSpacing.toStringAsFixed(1),
                    onChanged: widget.onLetterSpacingChanged,
                    accentColor: accentColor,
                  ),
                  _buildSliderTile(
                    label: '段间距',
                    value: widget.paragraphSpacing,
                    min: 4,
                    max: 32,
                    divisions: 14,
                    display: widget.paragraphSpacing.toStringAsFixed(0),
                    onChanged: widget.onParagraphSpacingChanged,
                    accentColor: accentColor,
                  ),
                  _buildSliderTile(
                    label: '页边距',
                    value: widget.pageMargin,
                    min: 8,
                    max: 40,
                    divisions: 16,
                    display: '${widget.pageMargin.toStringAsFixed(0)}px',
                    onChanged: widget.onPageMarginChanged,
                    accentColor: accentColor,
                  ),
                  const Divider(height: 20, indent: 16, endIndent: 16),
                  _buildSectionHeader(
                    icon: PhosphorIconsRegular.textT,
                    title: '文字排版',
                  ),
                  _buildSliderTile(
                    label: '字体大小',
                    value: widget.fontSize,
                    min: 12,
                    max: 32,
                    divisions: 20,
                    display: '${widget.fontSize.toStringAsFixed(0)}px',
                    onChanged: widget.onFontSizeChanged,
                    accentColor: accentColor,
                  ),
                  _buildSliderTile(
                    label: '行间距',
                    value: widget.lineHeight,
                    min: 1.0,
                    max: 3.0,
                    divisions: 20,
                    display: widget.lineHeight.toStringAsFixed(1),
                    onChanged: widget.onLineHeightChanged,
                    accentColor: accentColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color accentColor) {
    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
          widget.onClose();
        }
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: _mutedColor.withValues(alpha: 0.5),
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
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
      child: Row(
        children: [
          Icon(icon, size: 15, color: _mutedColor),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              color: _mutedColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector(Color accentColor) {
    final modes = [
      (ReadingMode.scroll, '滚动', PhosphorIconsRegular.arrowsDownUp),
      (ReadingMode.pageTurn, '翻页', PhosphorIconsRegular.book),
      (ReadingMode.pagination, '分页', PhosphorIconsFill.bookOpenText),
      (ReadingMode.bilingual, '对照', PhosphorIconsRegular.translate),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: modes.map((m) {
          final isSelected = widget.readingMode == m.$1;
          return GestureDetector(
            onTap: () => widget.onReadingModeChanged(m.$1),
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
                      : _mutedColor.withValues(alpha: 0.2),
                  width: isSelected ? 1.5 : 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    m.$3,
                    size: 14,
                    color: isSelected ? accentColor : _mutedColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    m.$2,
                    style: TextStyle(
                      color: isSelected ? accentColor : _textColor,
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

  Widget _buildWritingDirectionSelector(Color accentColor) {
    final directions = [
      (WritingDirection.horizontal, '横排', PhosphorIconsRegular.textT),
      (WritingDirection.vertical, '竖排', PhosphorIconsRegular.textAa),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: directions.map((d) {
          final isSelected = widget.writingDirection == d.$1;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: GestureDetector(
                onTap: () => widget.onWritingDirectionChanged(d.$1),
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
                          : _mutedColor.withValues(alpha: 0.2),
                      width: isSelected ? 1.5 : 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        d.$3,
                        size: 14,
                        color: isSelected ? accentColor : _mutedColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        d.$2,
                        style: TextStyle(
                          color: isSelected ? accentColor : _textColor,
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

  Widget _buildThemeSelector(Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: _buildChip(
              label: '浅色',
              icon: PhosphorIconsRegular.sun,
              selected: widget.themeMode == ThemeMode.light,
              accentColor: accentColor,
              onTap: () => widget.onThemeChanged(ThemeMode.light),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildChip(
              label: '深色',
              icon: PhosphorIconsRegular.moon,
              selected: widget.themeMode == ThemeMode.dark,
              accentColor: accentColor,
              onTap: () => widget.onThemeChanged(ThemeMode.dark),
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
    required Color accentColor,
    required VoidCallback onTap,
  }) {
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
            color: selected ? accentColor : _mutedColor.withValues(alpha: 0.2),
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: selected ? accentColor : _mutedColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? accentColor : _textColor,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBgColorPicker(Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '阅读背景',
            style: TextStyle(
              color: _mutedColor,
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(_bgColors.length, (i) {
              final isDark = _bgColors[i].computeLuminance() < 0.5;
              return GestureDetector(
                onTap: () => widget.onReaderBgColorChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _bgColors[i],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.readerBgColorIndex == i
                          ? accentColor
                          : _mutedColor.withValues(alpha: 0.15),
                      width: widget.readerBgColorIndex == i ? 2.5 : 1,
                    ),
                    boxShadow: widget.readerBgColorIndex == i
                        ? [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.2),
                              blurRadius: 4,
                              spreadRadius: 0,
                            ),
                          ]
                        : null,
                  ),
                  child: widget.readerBgColorIndex == i
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

  Widget _buildSliderTile({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String display,
    required ValueChanged<double> onChanged,
    required Color accentColor,
    Widget? preview,
  }) {
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
                  color: _textColor,
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
              inactiveTrackColor: _mutedColor.withValues(alpha: 0.12),
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
}
