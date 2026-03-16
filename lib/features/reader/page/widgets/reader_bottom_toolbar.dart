/// 阅读器底部工具栏
library;

import 'package:flutter/material.dart';

/// 阅读器底部工具栏
class ReaderBottomToolbar extends StatelessWidget {
  final int currentChapterId;
  final int currentPageIndex;
  final int totalPages;
  final ThemeMode themeMode;
  final VoidCallback onPreviousChapter;
  final VoidCallback onNextChapter;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;
  final VoidCallback onShowSettings;
  final ValueChanged<int>? onPageChanged;

  const ReaderBottomToolbar({
    super.key,
    required this.currentChapterId,
    required this.currentPageIndex,
    required this.totalPages,
    required this.themeMode,
    required this.onPreviousChapter,
    required this.onNextChapter,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onShowSettings,
    this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = themeMode == ThemeMode.dark
        ? Colors.black87
        : Colors.white;

    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 进度�?
             Row(
              children: [
                Expanded(
                  child: Slider(
                    value: totalPages > 0
                        ? (currentPageIndex + 1) / totalPages
                        : 0,
                    onChanged: totalPages > 0
                        ? (value) {
                            // 实现进度条拖�?
                                final targetPage = ((value * totalPages) - 1)
                                .toInt();
                            if (targetPage >= 0 && targetPage < totalPages) {
                              onPageChanged?.call(targetPage);
                            }
                          }
                        : null,
                    onChangeEnd: (value) {
                      // 释放时跳转到指定页面
                      final targetPage = ((value * totalPages) - 1).toInt();
                      if (targetPage >= 0 && targetPage < totalPages) {
                        onPageChanged?.call(targetPage);
                      }
                    },
                  ),
                ),
                Text(
                  '${currentPageIndex + 1}/$totalPages',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            // 控制按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  onPressed: onPreviousChapter,
                  tooltip: '上一�?',
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: onPreviousPage,
                  tooltip: '上一�?',
                ),
                Text(
                  '�?{currentChapterId + 1}�?',
                  style: const TextStyle(fontSize: 14),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: onNextPage,
                  tooltip: '下一�?',
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: onNextChapter,
                  tooltip: '下一�?',
                ),
              ],
            ),
            // 设置按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.settings),
                  label: const Text('设置'),
                  onPressed: onShowSettings,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
