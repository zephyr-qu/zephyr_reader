/// 阅读器设置对话框
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// 阅读器设置对话框
class ReaderSettingsDialog extends HookWidget {
  final double fontSize;
  final double lineHeight;
  final ThemeMode themeMode;
  final ValueChanged<double>? onFontSizeChanged;
  final ValueChanged<double>? onLineHeightChanged;
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  const ReaderSettingsDialog({
    super.key,
    required this.fontSize,
    required this.lineHeight,
    required this.themeMode,
    this.onFontSizeChanged,
    this.onLineHeightChanged,
    this.onThemeModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fontSizeState = useState(fontSize);
    final lineHeightState = useState(lineHeight);

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '阅读设置',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            // 字体大小
            const Text('字体大小'),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: fontSizeState.value,
                    min: 12,
                    max: 32,
                    divisions: 10,
                    label: fontSizeState.value.toStringAsFixed(0),
                    onChanged: (value) {
                      fontSizeState.value = value;
                      onFontSizeChanged?.call(value);
                    },
                  ),
                ),
                Text('${fontSizeState.value.toStringAsFixed(0)}px'),
              ],
            ),
            const SizedBox(height: 16),
            // 行间            const Text('行间),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: lineHeightState.value,
                    min: 1.0,
                    max: 2.0,
                    divisions: 20,
                    label: lineHeightState.value.toStringAsFixed(1),
                    onChanged: (value) {
                      lineHeightState.value = value;
                      onLineHeightChanged?.call(value);
                    },
                  ),
                ),
                Text(lineHeightState.value.toStringAsFixed(1)),
              ],
            ),
            const SizedBox(height: 24),
            // 主题选择
            const Text('主题'),
            Wrap(
              spacing: 8,
              children: [
                _buildThemeChip(context, '日间', ThemeMode.light),
                _buildThemeChip(context, '深色', ThemeMode.dark),
                _buildThemeChip(context, '护眼', ThemeMode.light), // 使用米黄色背
              ],
            ),
            const SizedBox(height: 24),
            // 关闭按钮
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeChip(BuildContext context, String label, ThemeMode mode) {
    final isSelected = themeMode == mode;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          onThemeModeChanged?.call(mode);
        }
      },
    );
  }
}
