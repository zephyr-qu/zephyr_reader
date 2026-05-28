import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/utils/adaptive_scroll_physics.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class _StatusTab {
  final BookStatus? status;
  final String label;
  const _StatusTab(this.status, this.label);
}

class BookshelfStatusTabs extends StatelessWidget {
  final BookStatus? selectedStatus;
  final ValueChanged<BookStatus?> onStatusChanged;

  const BookshelfStatusTabs({
    super.key,
    required this.selectedStatus,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const tabs = <_StatusTab>[
      _StatusTab(null, '全部'),
      _StatusTab(BookStatus.planned, '未开始'),
      _StatusTab(BookStatus.reading, '阅读中'),
      _StatusTab(BookStatus.completed, '已读完'),
    ];
    return SizedBox(
      height: 28,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: adaptiveScrollPhysics(context),
        itemCount: tabs.length,
        separatorBuilder: (_, _) =>
            SizedBox(width: DesignTokens.spacing(Spacing.md)),
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final isSelected = selectedStatus == tab.status;
          return RepaintBoundary(
            child: GestureDetector(
              onTap: () => onStatusChanged(tab.status),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tab.label,
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: isSelected
                          ? FontWeight.w500
                          : FontWeight.w400,
                    ),
                  ),
                  if (isSelected)
                    Container(
                      height: 1.5,
                      margin: EdgeInsets.only(
                        top: DesignTokens.spacing(Spacing.xs),
                      ),
                      color: theme.colorScheme.primary,
                    )
                  else
                    const SizedBox(height: 5.5),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
