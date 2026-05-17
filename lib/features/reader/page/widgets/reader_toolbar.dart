/// 阅读器顶部工具栏
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';

/// 阅读器顶部工具栏组件
class ReaderToolbar extends HookWidget {
  final String title;
  final String progress;
  final ThemeMode themeMode;
  final bool hasBookmark;
  final String bookId;
  final VoidCallback? onClose;
  final VoidCallback? onToggleToolbar;
  final VoidCallback? onShowCatalog;
  final VoidCallback? onShowBookmarks;
  final VoidCallback? onToggleBookmark;
  final VoidCallback? onShowSearch;
  final VoidCallback? onShowNotes;

  const ReaderToolbar({
    super.key,
    required this.title,
    this.progress = '',
    required this.themeMode,
    this.hasBookmark = false,
    required this.bookId,
    this.onClose,
    this.onToggleToolbar,
    this.onShowCatalog,
    this.onShowBookmarks,
    this.onToggleBookmark,
    this.onShowSearch,
    this.onShowNotes,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = themeMode == ThemeMode.dark
        ? const Color(0xFFF2F2F2)
        : const Color(0xFF1A1A1A);
    final backgroundColor = themeMode == ThemeMode.dark
        ? const Color(0xFF0A0A0A)
        : const Color(0xFFFAFAFA);

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
            GestureDetector(
              onLongPress: onToggleBookmark,
              child: IconButton(
                icon: Icon(
                  hasBookmark ? Icons.bookmark : Icons.bookmark_border,
                  color: hasBookmark ? Colors.blue : textColor,
                ),
                onPressed: onShowBookmarks,
                tooltip: '书签（长按快速添加/删除）',
              ),
            ),
            // 书签管理
            IconButton(
              icon: Icon(Icons.bookmarks_outlined, color: textColor, size: 20),
              onPressed: () => context.pushNamed(RouteNames.bookmarkManage,
                pathParameters: {'bookId': bookId}),
              tooltip: '书签管理',
            ),
            // 全书搜索
            IconButton(
              icon: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF4FC3F7), Color(0xFF7E57C2)],
                ).createShader(bounds),
                child: const Icon(Icons.search, color: Colors.white, size: 20),
              ),
              onPressed: () => context.pushNamed(RouteNames.bookSearch,
                queryParameters: {'bookId': bookId}),
              tooltip: '全书搜索',
            ),
            // 笔记侧边栏
            IconButton(
              icon: Icon(Icons.note_alt_outlined, color: textColor, size: 20),
              onPressed: onShowNotes,
              tooltip: '笔记侧边栏',
            ),
            // 章节内搜索
            IconButton(
              icon: const Icon(Icons.find_in_page, color: Colors.orange, size: 20),
              onPressed: onShowSearch,
              tooltip: '章节内搜索',
            ),
          ],
        ),
      ),
    );
  }
}
