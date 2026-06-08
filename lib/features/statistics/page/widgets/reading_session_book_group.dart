import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/core/utils/format_utils.dart';
import 'package:zephyr_reader/core/utils/time_formatters.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

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
    final totalChars = sessions.fold<int>(
      0,
      (sum, s) => sum + (s.endCharOffset - s.startCharOffset),
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
                onTap: onDelete,
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
              formatChars(totalChars, l10n),
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
    final chars = s.endCharOffset - s.startCharOffset;

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
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  l10n.chapterInfo(s.chapterIndex, formatChars(chars, l10n)),
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
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
