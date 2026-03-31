/// 阅读器设置对话框 - 优化版
library;

import 'package:flutter/material.dart';
import 'package:zephyr_reader/shared/widget/ui_components.dart';

/// 阅读器设置对话框
class ReaderSettingsDialog extends StatelessWidget {
  final double fontSize;
  final double lineHeight;
  final ThemeMode themeMode;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<double> onLineHeightChanged;
  final ValueChanged<ThemeMode> onThemeChanged;

  const ReaderSettingsDialog({
    super.key,
    required this.fontSize,
    required this.lineHeight,
    required this.themeMode,
    required this.onFontSizeChanged,
    required this.onLineHeightChanged,
    required this.onThemeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部指示器
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 标题
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.palette_outlined,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '阅读设置',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          // 设置内容
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 主题选择
                Text(
                  '主题模式',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ReaderThemeSelector(
                  selectedTheme: themeMode,
                  onThemeChanged: onThemeChanged,
                ),
                const SizedBox(height: 24),
                // 字体大小
                ReaderSlider(
                  label: '字体大小',
                  valueLabel: fontSize.toStringAsFixed(0),
                  value: fontSize,
                  min: 12,
                  max: 32,
                  divisions: 20,
                  onChanged: onFontSizeChanged,
                  icon: Icons.text_fields,
                ),
                const SizedBox(height: 24),
                // 行间距
                ReaderSlider(
                  label: '行间距',
                  valueLabel: lineHeight.toStringAsFixed(1),
                  value: lineHeight,
                  min: 1.0,
                  max: 2.5,
                  divisions: 15,
                  onChanged: onLineHeightChanged,
                  icon: Icons.format_line_spacing,
                ),
              ],
            ),
          ),
          // 底部按钮
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('关闭'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('完成'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 显示阅读器设置对话框
Future<void> showReaderSettingsDialog({
  required BuildContext context,
  required double fontSize,
  required double lineHeight,
  required ThemeMode themeMode,
  required ValueChanged<double> onFontSizeChanged,
  required ValueChanged<double> onLineHeightChanged,
  required ValueChanged<ThemeMode> onThemeChanged,
}) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ReaderSettingsDialog(
      fontSize: fontSize,
      lineHeight: lineHeight,
      themeMode: themeMode,
      onFontSizeChanged: onFontSizeChanged,
      onLineHeightChanged: onLineHeightChanged,
      onThemeChanged: onThemeChanged,
    ),
  );
}
