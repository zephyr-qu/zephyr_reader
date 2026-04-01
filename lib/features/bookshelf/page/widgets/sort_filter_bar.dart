/// 排序筛选栏组件
library;

import 'package:flutter/material.dart';
import 'package:zephyr_reader/features/bookshelf/domain/models/bookshelf_filter.dart';

/// 排序筛选栏
class SortFilterBar extends StatelessWidget {
  const SortFilterBar({
    super.key,
    required this.filter,
    required this.onSortChange,
  });

  /// 当前筛选条
  final BookshelfFilter filter;

  /// 排序变化回调
  final Function(BookshelfSortType sortType, bool ascending) onSortChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          // 排序方式
          Expanded(
            child: PopupMenuButton<BookshelfSortType>(
              child: Row(
                children: [
                  const Icon(Icons.sort, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _getSortTypeText(filter.sortType),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  Icon(
                    filter.ascending
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              onSelected: (sortType) {
                onSortChange(sortType, filter.ascending);
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: BookshelfSortType.lastRead,
                  child: Row(
                    children: [
                      if (filter.sortType == BookshelfSortType.lastRead)
                        Icon(
                          Icons.check,
                          color: theme.colorScheme.primary,
                          size: 20,
                        )
                      else
                        const SizedBox(width: 20),
                      const SizedBox(width: 8),
                      const Icon(Icons.history, size: 20),
                      const SizedBox(width: 12),
                      const Text('最后阅'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: BookshelfSortType.createdAt,
                  child: Row(
                    children: [
                      if (filter.sortType == BookshelfSortType.createdAt)
                        Icon(
                          Icons.check,
                          color: theme.colorScheme.primary,
                          size: 20,
                        )
                      else
                        const SizedBox(width: 20),
                      const SizedBox(width: 8),
                      const Icon(Icons.access_time, size: 20),
                      const SizedBox(width: 12),
                      const Text('添加时间'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: BookshelfSortType.title,
                  child: Row(
                    children: [
                      if (filter.sortType == BookshelfSortType.title)
                        Icon(
                          Icons.check,
                          color: theme.colorScheme.primary,
                          size: 20,
                        )
                      else
                        const SizedBox(width: 20),
                      const SizedBox(width: 8),
                      const Icon(Icons.title, size: 20),
                      const SizedBox(width: 12),
                      const Text('书名'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: BookshelfSortType.author,
                  child: Row(
                    children: [
                      if (filter.sortType == BookshelfSortType.author)
                        Icon(
                          Icons.check,
                          color: theme.colorScheme.primary,
                          size: 20,
                        )
                      else
                        const SizedBox(width: 20),
                      const SizedBox(width: 8),
                      const Icon(Icons.person, size: 20),
                      const SizedBox(width: 12),
                      const Text('作'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: BookshelfSortType.progress,
                  child: Row(
                    children: [
                      if (filter.sortType == BookshelfSortType.progress)
                        Icon(
                          Icons.check,
                          color: theme.colorScheme.primary,
                          size: 20,
                        )
                      else
                        const SizedBox(width: 20),
                      const SizedBox(width: 8),
                      const Icon(Icons.trending_up, size: 20),
                      const SizedBox(width: 12),
                      const Text('进度'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 切换排序方向
          IconButton(
            icon: Icon(
              filter.ascending ? Icons.arrow_upward : Icons.arrow_downward,
            ),
            onPressed: () {
              onSortChange(filter.sortType, !filter.ascending);
            },
            tooltip: filter.ascending ? '降序' : '升序',
          ),
        ],
      ),
    );
  }

  String _getSortTypeText(BookshelfSortType type) {
    switch (type) {
      case BookshelfSortType.lastRead:
        return '最后阅读';
      case BookshelfSortType.createdAt:
        return '添加时间';
      case BookshelfSortType.title:
        return '书名';
      case BookshelfSortType.author:
        return '作者';
      case BookshelfSortType.progress:
        return '进度';
    }
  }
}
