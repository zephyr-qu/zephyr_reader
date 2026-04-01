/// 阅读器顶部工具栏
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// 阅读器顶部工具栏组件
class ReaderToolbar extends HookWidget {
  /// 书籍/章节标题
  final String title;

  /// 进度文本
  final String progress;

  /// 主题模式
  final ThemeMode themeMode;

  /// 关闭回调
  final VoidCallback? onClose;

  /// 切换工具栏回调
  final VoidCallback? onToggleToolbar;

  /// 显示章节列表回调
  final VoidCallback? onShowCatalog;

  /// 显示书签列表回调
  final VoidCallback? onShowBookmarks;

  const ReaderToolbar({
    super.key,
    required this.title,
    this.progress = '',
    required this.themeMode,
    this.onClose,
    this.onToggleToolbar,
    this.onShowCatalog,
    this.onShowBookmarks,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = themeMode == ThemeMode.dark
        ? Colors.grey[300]!
        : Colors.black87;
    final backgroundColor = themeMode == ThemeMode.dark
        ? const Color(0xFF1a1a1a)
        : const Color(0xFFF5F5DC);

    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SafeArea(
        child: Row(
          children: [
            // 关闭按钮
            IconButton(
              icon: Icon(Icons.close, color: textColor),
              onPressed: onClose,
              tooltip: '关闭',
            ),
            // 目录按钮
            IconButton(
              icon: Icon(Icons.list, color: textColor),
              onPressed: onShowCatalog,
              tooltip: '目录',
            ),
            // 标题和进度
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (progress.isNotEmpty)
                    Text(
                      progress,
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            // 书签按钮
            IconButton(
              icon: Icon(Icons.bookmark_border, color: textColor),
              onPressed: onShowBookmarks,
              tooltip: '书签',
            ),
          ],
        ),
      ),
    );
  }
}
