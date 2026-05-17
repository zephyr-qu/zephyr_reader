/// 阅读器设置面板
library;

import 'package:flutter/material.dart';

import '../../application/reader_view_model.dart';

/// 阅读器设置面板
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
  @override
  Widget build(BuildContext context) {
    final textColor = _getTextColor(widget.themeMode);
    final backgroundColor = _getBackgroundColor(widget.themeMode);

    return Container(
      color: backgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: textColor.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '设置',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: textColor),
                    onPressed: widget.onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // 设置内容
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 阅读模式
                  _buildSettingSection(
                    title: '阅读模式',
                    child: Row(
                      children: [
                        _buildChoiceChip(
                          label: '滚动',
                          selected: widget.readingMode == ReadingMode.scroll,
                          onTap: () =>
                              widget.onReadingModeChanged(ReadingMode.scroll),
                          textColor: textColor,
                        ),
                        const SizedBox(width: 16),
                        _buildChoiceChip(
                          label: '分页',
                          selected:
                              widget.readingMode == ReadingMode.pagination,
                          onTap: () => widget.onReadingModeChanged(
                            ReadingMode.pagination,
                          ),
                          textColor: textColor,
                        ),
                        const SizedBox(width: 16),
                        _buildChoiceChip(
                          label: '对照',
                          selected:
                              widget.readingMode == ReadingMode.bilingual,
                          onTap: () => widget.onReadingModeChanged(
                            ReadingMode.bilingual,
                          ),
                          textColor: textColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 字体大小
                  _buildSettingSection(
                    title: '字体大小：${widget.fontSize.toStringAsFixed(1)}',
                    child: Column(
                      children: [
                        Slider(
                          value: widget.fontSize,
                          min: 12,
                          max: 32,
                          divisions: 20,
                          onChanged: widget.onFontSizeChanged,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('小', style: TextStyle(color: textColor)),
                            Text('大', style: TextStyle(color: textColor)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 行间距
                  _buildSettingSection(
                    title: '行间距：${widget.lineHeight.toStringAsFixed(1)}',
                    child: Column(
                      children: [
                        Slider(
                          value: widget.lineHeight,
                          min: 1.0,
                          max: 3.0,
                          divisions: 20,
                          onChanged: widget.onLineHeightChanged,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('密', style: TextStyle(color: textColor)),
                            Text('疏', style: TextStyle(color: textColor)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 主题
                  _buildSettingSection(
                    title: '主题',
                    child: Row(
                      children: [
                        _buildChoiceChip(
                          label: '浅色',
                          selected: widget.themeMode == ThemeMode.light,
                          onTap: () => widget.onThemeChanged(ThemeMode.light),
                          textColor: textColor,
                        ),
                        const SizedBox(width: 16),
                        _buildChoiceChip(
                          label: '深色',
                          selected: widget.themeMode == ThemeMode.dark,
                          onTap: () => widget.onThemeChanged(ThemeMode.dark),
                          textColor: textColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 书写方向
                  _buildSettingSection(
                    title: '书写方向',
                    child: Row(
                      children: [
                        _buildChoiceChip(
                          label: '横排',
                          selected: widget.writingDirection == WritingDirection.horizontal,
                          onTap: () => widget.onWritingDirectionChanged(WritingDirection.horizontal),
                          textColor: textColor,
                        ),
                        const SizedBox(width: 16),
                        _buildChoiceChip(
                          label: '竖排',
                          selected: widget.writingDirection == WritingDirection.vertical,
                          onTap: () => widget.onWritingDirectionChanged(WritingDirection.vertical),
                          textColor: textColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 字间距
                  _buildSettingSection(
                    title: '字间距：${widget.letterSpacing.toStringAsFixed(1)}',
                    child: Column(
                      children: [
                        Slider(
                          value: widget.letterSpacing,
                          min: 0,
                          max: 8,
                          divisions: 16,
                          onChanged: widget.onLetterSpacingChanged,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('常规', style: TextStyle(color: textColor)),
                            Text('宽松', style: TextStyle(color: textColor)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 段间距
                  _buildSettingSection(
                    title: '段间距：${widget.paragraphSpacing.toStringAsFixed(0)}',
                    child: Column(
                      children: [
                        Slider(
                          value: widget.paragraphSpacing,
                          min: 4,
                          max: 32,
                          divisions: 14,
                          onChanged: widget.onParagraphSpacingChanged,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('小', style: TextStyle(color: textColor)),
                            Text('大', style: TextStyle(color: textColor)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 页边距
                  _buildSettingSection(
                    title: '页边距：${widget.pageMargin.toStringAsFixed(0)}',
                    child: Column(
                      children: [
                        Slider(
                          value: widget.pageMargin,
                          min: 8,
                          max: 40,
                          divisions: 16,
                          onChanged: widget.onPageMarginChanged,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('窄', style: TextStyle(color: textColor)),
                            Text('宽', style: TextStyle(color: textColor)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 阅读背景色
                  _buildSettingSection(
                    title: '阅读背景色',
                    child: Wrap(
                      spacing: 8,
                      children: [
                        _buildColorChip('默认', 0, textColor),
                        _buildColorChip('羊皮纸', 1, textColor),
                        _buildColorChip('奶油', 2, textColor),
                        _buildColorChip('护眼绿', 3, textColor),
                        _buildColorChip('灰色', 4, textColor),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 亮度
                  _buildSettingSection(
                    title: '亮度：${((1 - widget.brightnessValue) * 100).toStringAsFixed(0)}%',
                    child: Column(
                      children: [
                        Slider(
                          value: 1 - widget.brightnessValue,
                          min: 0.3,
                          max: 1.0,
                          divisions: 14,
                          onChanged: (v) => widget.onBrightnessChanged(1 - v),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('暗', style: TextStyle(color: textColor)),
                            Text('亮', style: TextStyle(color: textColor)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingSection({required String title, required Widget child}) {
    final textColor = _getTextColor(widget.themeMode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  static const _bgColors = [Color(0xFFFAFAFA), Color(0xFFF5F0E8), Color(0xFFFFF8E7), Color(0xFFC7EDCC), Color(0xFFF0F0F0)];

  Widget _buildColorChip(String label, int index, Color textColor) {
    final selected = widget.readerBgColorIndex == index;
    return GestureDetector(
      onTap: () => widget.onReaderBgColorChanged(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _bgColors[index] : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? _bgColors[index] : textColor.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, color: selected ? Colors.black87 : textColor)),
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required Color textColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? textColor.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: textColor, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Color _getTextColor(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.dark:
        return const Color(0xFFF2F2F2);
      case ThemeMode.light:
      default:
        return const Color(0xFF1A1A1A);
    }
  }

  Color _getBackgroundColor(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.dark:
        return const Color(0xFF0A0A0A);
      case ThemeMode.light:
      default:
        return const Color(0xFFFAFAFA);
    }
  }
}
