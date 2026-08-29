import 'package:zephyr_reader/src/rust/domain/sessions/models.dart';
import 'package:zephyr_reader/src/rust/domain/book/models.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/presentation/widgets/confirm_action_dialog.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/core/utils/time_formatters.dart';


/// 按书籍分组的阅读会话区块。
///
/// 显示书名（从 [bookCache] 解析）、删除整组按钮、以及该书籍下所有
/// 会话的汇总（总时长、总字数）及逐条记录。
class ReadingSessionBookGroup extends StatelessWidget {
  final String bookId;
  final List<ReadingSession> sessions;
  final Map<String, Book> bookCache;
  final VoidCallback onDelete;

  const ReadingSessionBookGroup({
    super.key,
    required this.bookId,
    required this.sessions,
    required this.bookCache,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final book = bookCache[bookId];
    final bookTitle = book?.title ?? l10n.unknownBook;
    final totalTime = sessions.fold<int>(
      0,
      (sum, s) => sum + s.durationSeconds,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  bookTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => showConfirmActionDialog(
                  context,
                  title: l10n.deleteSessionTitle,
                  content: l10n.deleteSessionConfirm,
                  confirmLabel: l10n.delete,
                  onConfirm: onDelete,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    PhosphorIconsRegular.trash,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            l10n.sessionSummary(
              sessions.length,
              formatDuration(totalTime, l10n),
            ),
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ...sessions.map((s) => _buildSessionTile(context, s)),
      ],
    );
  }

  Widget _buildSessionTile(BuildContext context, ReadingSession s) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final dateStr = DateFormat('MM/dd HH:mm').format(s.startedAt);
    final duration = formatDuration(s.durationSeconds, l10n);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(
            PhosphorIconsRegular.playCircle,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateStr,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  l10n.chapterInfo(s.chapterIndex),
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            duration,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
