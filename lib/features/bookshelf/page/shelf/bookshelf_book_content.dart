import 'dart:io';
import 'package:flutter/material.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/presentation/widgets/skeleton_widget.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zephyr_reader/core/utils/adaptive_scroll_physics.dart';
import 'package:zephyr_reader/core/presentation/widgets/adaptive_layout.dart';
import 'package:zephyr_reader/core/utils/cover_utils.dart';
import 'package:flutter/services.dart';
import 'package:zephyr_reader/features/bookshelf/page/widgets/book_cover.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 书架书籍内容网格。
///
/// 以网格布局展示书籍封面，支持加载态、空态、错误态和批量选择模式。
class BookshelfBookContent extends StatelessWidget {
  final bool isLoading;
  final bool hasError;
  final List<Book> books;
  final int crossAxisCount;
  final bool isListView;
  final bool batchMode;
  final Set<String> selectedIds;
  final VoidCallback onRetry;
  final VoidCallback onImportTap;
  final VoidCallback onRefresh;
  final ValueChanged<Set<String>> onSelectionChanged;
  final void Function(Book) onBookTap;
  final void Function(Book) onBookLongPress;
  final Map<String, double> readingProgress;
  final bool showProgressBadge;

  const BookshelfBookContent({
    super.key,
    required this.isLoading,
    required this.hasError,
    required this.books,
    required this.crossAxisCount,
    required this.isListView,
    required this.batchMode,
    required this.selectedIds,
    required this.onRetry,
    required this.onImportTap,
    required this.onRefresh,
    required this.onSelectionChanged,
    required this.onBookTap,
    required this.onBookLongPress,
    required this.readingProgress,
    required this.showProgressBadge,
  });

  String _statusLabel(BuildContext context, String statusName) {
    final l10n = AppLocalizations.of(context)!;
    return switch (statusName) {
      'reading' => l10n.reading,
      'completed' => l10n.finished,
      _ => l10n.notStarted,
    };
  }

  /// 共享 item 包裹器：手势/动画/选择态背景。
  Widget _buildBookItemWrapper({
    required int index,
    required Book book,
    required bool selected,
    required Widget child,
    EdgeInsetsGeometry? outerPadding,
    BorderRadius? inkWellBorderRadius,
    Color? selectedBackgroundColor,
    bool slideFromRight = false,
  }) {
    Widget content = child;
    if (selectedBackgroundColor != null && selected) {
      content = Container(
        decoration: BoxDecoration(
          color: selectedBackgroundColor,
          borderRadius: inkWellBorderRadius,
        ),
        child: content,
      );
    }

    content = slideFromRight
        ? content
            .animate(delay: (index * 80).ms)
            .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic)
            .slideX(
              begin: 0.05, end: 0, duration: 400.ms, curve: Curves.easeOutCubic)
        : content
            .animate(delay: (index * 80).ms)
            .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic)
            .slideY(
              begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutCubic);

    content = InkWell(
      onTap: batchMode
          ? () {
              if (selected) {
                onSelectionChanged(
                  selectedIds.where((id) => id != book.bookId).toSet(),
                );
              } else {
                onSelectionChanged({...selectedIds, book.bookId});
              }
            }
          : () => onBookTap(book),
      onLongPress: () {
        if (!batchMode) {
          HapticFeedback.mediumImpact();
          onBookLongPress(book);
        }
      },
      borderRadius: inkWellBorderRadius,
      child: content,
    );

    if (outerPadding != null) {
      content = Padding(padding: outerPadding, child: content);
    }

    return RepaintBoundary(
      key: ValueKey('book_${book.bookId}'),
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    if (isLoading) return const SkeletonGrid();
    if (hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.loadFailed,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            SizedBox(height: Spacing.sm.value),
            TextButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      );
    }
    if (books.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIconsRegular.book,
              size: IconSize.hero,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            SizedBox(height: Spacing.md.value),
            Text(
              l10n.bookshelfEmpty,
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: Spacing.md.value),
            FilledButton.tonalIcon(
              onPressed: onImportTap,
              icon: const Icon(PhosphorIconsRegular.uploadSimple, size: 18),
              label: Text(l10n.importBook),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: switch (LayoutBreakpoints.getScreenSizeClass(context)) {
              ScreenSizeClass.expanded => 1200,
              _ => LayoutBreakpoints.expandedMin,
            },
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              Spacing.lg.value,
              20,
              Spacing.lg.value,
              batchMode ? 80 : 0,
            ),
            child: isListView
                ? _buildListContent(context, theme, l10n)
                : _buildGridContent(context, theme, l10n),
          ),
        ),
      ),
    );
  }

  Widget _buildGridContent(BuildContext context, ThemeData theme, AppLocalizations l10n) {
    final cs = theme.colorScheme;
    return GridView.builder(
      key: const Key('bookshelf_grid'),
      itemCount: books.length,
      physics: adaptiveScrollPhysics(
        context,
        physics: const AlwaysScrollableScrollPhysics(),
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.62,
        crossAxisSpacing: 14,
        mainAxisSpacing: 18,
      ),
      itemBuilder: (context, index) {
        final book = books[index];
        final selected = selectedIds.contains(book.bookId);
        return _buildBookItemWrapper(
          index: index,
          book: book,
          selected: selected,
          child: Stack(
            children: [
              BookCover(
                book: book,
                statusLabel: _statusLabel(context, book.status.name),
                progress: showProgressBadge ? readingProgress[book.bookId] : null,
              ),
              if (batchMode)
                Positioned(
                  top: 4, right: 4,
                  child: Icon(
                    selected
                        ? PhosphorIconsFill.checkCircle
                        : PhosphorIconsRegular.circle,
                    color: selected
                        ? cs.primary
                        : Colors.white.withValues(alpha: 0.6),
                    size: 22,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListContent(BuildContext context, ThemeData theme, AppLocalizations l10n) {
    final cs = theme.colorScheme;
    return ListView.builder(
      key: const Key('bookshelf_list'),
      itemCount: books.length,
      physics: adaptiveScrollPhysics(
        context,
        physics: const AlwaysScrollableScrollPhysics(),
      ),
      itemBuilder: (context, index) {
        final book = books[index];
        final selected = selectedIds.contains(book.bookId);
        final progress = showProgressBadge ? readingProgress[book.bookId] : null;
        return _buildBookItemWrapper(
          index: index,
          book: book,
          selected: selected,
          outerPadding: EdgeInsets.only(
            left: 4, right: 4,
            bottom: index < books.length - 1 ? 8 : 0,
          ),
          inkWellBorderRadius: BorderRadius.circular(RadiusSize.lg.value),
          selectedBackgroundColor: cs.primaryContainer.withValues(alpha: 0.15),
          slideFromRight: true,
          child: Stack(
            children: [
              // Main content row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cover with shadow
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(RadiusSize.sm.value),
                        boxShadow: [DesignTokens.cardShadow],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(RadiusSize.sm.value),
                        child: SizedBox(
                          width: 100, height: 150,
                          child: book.coverPath != null
                              ? Image.file(
                                  File(resolveCoverPath(book.coverPath!)!),
                                  fit: BoxFit.cover,
                                  width: 100, height: 150,
                                  cacheWidth: 200,
                                  errorBuilder: (_, _, _) => Container(
                                    color: cs.primaryContainer.withValues(alpha: 0.5),
                                    child: Center(child: Icon(PhosphorIconsRegular.book, size: 28, color: cs.primary.withValues(alpha: 0.35))),
                                  ),
                                )
                              : Container(
                                  color: cs.primaryContainer.withValues(alpha: 0.5),
                                  child: Center(child: Icon(PhosphorIconsRegular.book, size: 28, color: cs.primary.withValues(alpha: 0.35))),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Book details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title row (with optional pin icon)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: cs.onSurface, height: 1.3, letterSpacing: -0.3)),
                              ),
                              if (book.isPinned)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6, top: 2),
                                  child: Icon(PhosphorIconsFill.pushPin, size: 14, color: DesignTokens.warmAccent.withValues(alpha: 0.5)),
                                ),
                            ],
                          ),
                          // Author
                          if (book.author != null && book.author!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text('·', style: TextStyle(fontSize: 15, color: DesignTokens.warmAccent.withValues(alpha: 0.5), fontWeight: FontWeight.w700, height: 1)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(book.author!, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant, height: 1.3)),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 10),
                          // Status & progress row
                          Row(
                            children: [
                              // Status pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _statusColor(cs, book.status.name).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(_statusLabel(context, book.status.name),
                                  style: TextStyle(fontSize: 11, color: _statusColor(cs, book.status.name), fontWeight: FontWeight.w600, height: 1.2)),
                              ),
                              if (progress != null && progress > 0) ...[
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value: progress, minHeight: 5,
                                      backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('${(progress * 100).round()}%', style: const TextStyle(fontSize: 11, color: DesignTokens.warmAccent, fontWeight: FontWeight.w700, height: 1.2)),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Right side: chapter count or batch checkbox
                    if (!batchMode)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Icon(PhosphorIconsRegular.caretRight, size: 16, color: cs.onSurfaceVariant.withValues(alpha: 0.2)),
                            if (book.chapterCount > 0) ...[
                              const SizedBox(height: 4),
                              Text(l10n.totalChapters(book.chapterCount), style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant.withValues(alpha: 0.4), height: 1.2)),
                            ],
                          ],
                        ),
                      ),
                    if (batchMode)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          selected ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.circle,
                          color: selected ? cs.primary : cs.onSurfaceVariant.withValues(alpha: 0.4),
                          size: 22,
                        ),
                      ),
                  ],
                ),
              ),
              // Left reading-progress accent ribbon
              if (progress != null && progress > 0)
                Positioned(
                  left: 0, top: 0, bottom: 0,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter, end: Alignment.topCenter,
                        stops: [progress, progress],
                        colors: [DesignTokens.warmAccent.withValues(alpha: 0.55), Colors.transparent],
                      ),
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(1.5), bottomLeft: Radius.circular(1.5)),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Color _statusColor(ColorScheme cs, String statusName) {
    return switch (statusName) {
      'reading' => cs.primary,
      'completed' => cs.tertiary,
      _ => cs.onSurfaceVariant.withValues(alpha: 0.6),
    };
  }
}
