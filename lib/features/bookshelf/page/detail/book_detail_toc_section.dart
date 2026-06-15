import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 目录手风琴
class BookDetailTocSection extends StatelessWidget {
  final List<Chapter> chapters;
  final bool showAll;
  final int currentChapterIndex;
  final VoidCallback? onToggleExpand;
  final void Function(int chapterIndex) onChapterTap;

  const BookDetailTocSection({
    super.key,
    required this.chapters,
    required this.showAll,
    required this.currentChapterIndex,
    this.onToggleExpand,
    required this.onChapterTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    if (chapters.isEmpty) return const SizedBox.shrink();

    final displayChapters = showAll ? chapters : chapters.take(5).toList();
    final hasMore = chapters.length > 5;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: hasMore ? onToggleExpand : null,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.tocTitle(chapters.length),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (hasMore)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          showAll ? l10n.collapse : l10n.expand,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          showAll
                              ? PhosphorIconsRegular.caretUp
                              : PhosphorIconsRegular.caretDown,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          // Divider
          Divider(height: 1, color: theme.dividerColor),
          // List
          ...displayChapters.asMap().entries.map((entry) {
            final idx = entry.key;
            final chapter = entry.value;
            final isCurrent =
                currentChapterIndex >= 0 &&
                chapter.chapterIndex == currentChapterIndex;
            return InkWell(
              onTap: () => onChapterTap(chapter.chapterIndex),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.4,
                        )
                      : null,
                  border: idx < displayChapters.length - 1
                      ? Border(
                          bottom: BorderSide(
                            color: theme.dividerColor,
                            width: 0.5,
                          ),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        chapter.title,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: isCurrent
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isCurrent
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrent)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.dark
                              ? const Color(0xFFFFB74D)
                              : const Color(0xFFFFA726),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          l10n.currentChapter,
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
