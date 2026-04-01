/// 阅读器设置面板
library;

import 'package:flutter/material.dart';

import '../../application/reader_view_model.dart';

/// 阅读器设置面板
class ReaderSettingsPanel extends StatefulWidget {
  /// 主题模式
  final ThemeMode themeMode;

  /// 阅读模式
  final ReadingMode readingMode;

  /// 字体大小
  final double fontSize;

  /// 行间距
  final double lineHeight;

  /// 阅读模式变化回调
  final ValueChanged<ReadingMode> onReadingModeChanged;

  /// 字体大小变化回调
  final ValueChanged<double> onFontSizeChanged;

  /// 行间距变化回调
  final ValueChanged<double> onLineHeightChanged;

  /// 主题变化回调
  final ValueChanged<ThemeMode> onThemeChanged;

  /// 关闭回调
  final VoidCallback onClose;

  const ReaderSettingsPanel({
    super.key,
    required this.themeMode,
    required this.readingMode,
    required this.fontSize,
    required this.lineHeight,
    required this.onReadingModeChanged,
    required this.onFontSizeChanged,
    required this.onLineHeightChanged,
    required this.onThemeChanged,
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
                          selected: widget.readingMode == ReadingMode.pagination,
                          onTap: () =>
                              widget.onReadingModeChanged(ReadingMode.pagination),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingSection({
    required String title,
    required Widget child,
  }) {
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
          color: selected ? textColor.withValues(alpha: 0.2) : Colors.transparent,
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
        return Colors.grey[300]!;
      case ThemeMode.light:
      default:
        return Colors.black87;
    }
  }

  Color _getBackgroundColor(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.dark:
        return const Color(0xFF1a1a1a);
      case ThemeMode.light:
      default:
        return const Color(0xFFF5F5DC);
    }
  }
}
