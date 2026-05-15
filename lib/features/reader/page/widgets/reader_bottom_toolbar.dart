/// 阅读器底部工具栏
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// 阅读器底部工具栏组件
class ReaderBottomToolbar extends HookWidget {
  /// 当前章节 ID
  final int currentChapterId;

  /// 当前页码
  final int currentPageIndex;

  /// 总页数
  final int totalPages;

  /// 主题模式
  final ThemeMode themeMode;

  /// 上一章回调
  final VoidCallback? onPreviousChapter;

  /// 下一章回调
  final VoidCallback? onNextChapter;

  /// 上一页回调
  final VoidCallback? onPreviousPage;

  /// 下一页回调
  final VoidCallback? onNextPage;

  /// 显示设置回调
  final VoidCallback? onShowSettings;

  const ReaderBottomToolbar({
    super.key,
    required this.currentChapterId,
    required this.currentPageIndex,
    required this.totalPages,
    required this.themeMode,
    this.onPreviousChapter,
    this.onNextChapter,
    this.onPreviousPage,
    this.onNextPage,
    this.onShowSettings,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = themeMode == ThemeMode.dark
        ? const Color(0xFFF2F2F2)
        : const Color(0xFF1A1A1A);
    final backgroundColor = themeMode == ThemeMode.dark
        ? const Color(0xFF0A0A0A)
        : const Color(0xFFFAFAFA);

    final hasPreviousChapter = onPreviousChapter != null;
    final hasNextChapter = onNextChapter != null;
    final canPreviousPage = currentPageIndex > 0;
    final canNextPage = currentPageIndex < totalPages - 1;

    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 进度条
            Row(
              children: [
                Text(
                  '第 ${currentChapterId + 1} 章',
                  style: TextStyle(color: textColor, fontSize: 12),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: LinearProgressIndicator(
                      value: totalPages > 0
                          ? (currentPageIndex + 1) / totalPages
                          : 0,
                      backgroundColor: textColor.withValues(alpha: 0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        textColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ),
                Text(
                  '$currentPageIndex / $totalPages',
                  style: TextStyle(color: textColor, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 控制按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // 上一章
                _buildButton(
                  icon: Icons.skip_previous,
                  label: '上一章',
                  onPressed: hasPreviousChapter ? onPreviousChapter : null,
                  textColor: textColor,
                ),
                // 上一页
                _buildButton(
                  icon: Icons.arrow_back_ios,
                  label: '上一页',
                  onPressed: canPreviousPage ? onPreviousPage : null,
                  textColor: textColor,
                ),
                // 设置
                _buildButton(
                  icon: Icons.settings,
                  label: '设置',
                  onPressed: onShowSettings,
                  textColor: textColor,
                ),
                // 下一页
                _buildButton(
                  icon: Icons.arrow_forward_ios,
                  label: '下一页',
                  onPressed: canNextPage ? onNextPage : null,
                  textColor: textColor,
                ),
                // 下一章
                _buildButton(
                  icon: Icons.skip_next,
                  label: '下一章',
                  onPressed: hasNextChapter ? onNextChapter : null,
                  textColor: textColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required Color textColor,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: onPressed != null
                  ? textColor
                  : textColor.withValues(alpha: 0.3),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: onPressed != null
                    ? textColor
                    : textColor.withValues(alpha: 0.3),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
