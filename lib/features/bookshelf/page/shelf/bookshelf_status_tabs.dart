import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/utils/adaptive_scroll_physics.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 阅读状态标签栏。
///
/// 以横向滚动的标签形式展示书籍阅读状态（在读/已读完/未读等），支持筛选。
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
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 28,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: adaptiveScrollPhysics(context),
        itemCount: _statusTabs.length,
        separatorBuilder: (_, _) => SizedBox(width: Spacing.md.value),
        itemBuilder: (context, index) {
          final tab = _statusTabs[index];
          final isSelected = selectedStatus == tab.status;
          return RepaintBoundary(
            child: InkWell(
              onTap: () => onStatusChanged(tab.status),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tab.label(l10n),
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
                      margin: EdgeInsets.only(top: Spacing.xs.value),
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

class _StatusTab {
  final BookStatus? status;
  final String Function(AppLocalizations) label;

  const _StatusTab(this.status, this.label);
}

const _statusTabs = [
  _StatusTab(null, _all),
  _StatusTab(BookStatus.planned, _notStarted),
  _StatusTab(BookStatus.reading, _reading),
  _StatusTab(BookStatus.completed, _finished),
];

String _all(AppLocalizations l) => l.all;
String _notStarted(AppLocalizations l) => l.notStarted;
String _reading(AppLocalizations l) => l.reading;
String _finished(AppLocalizations l) => l.finished;
