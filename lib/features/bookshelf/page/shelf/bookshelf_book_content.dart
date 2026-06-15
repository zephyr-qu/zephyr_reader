import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/presentation/widgets/adaptive_layout.dart';
import 'package:zephyr_reader/core/presentation/widgets/skeleton_widget.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/utils/adaptive_scroll_physics.dart';
import 'package:zephyr_reader/core/utils/cover_utils.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/bookshelf/application/bookshelf_view_model.dart';
import 'package:zephyr_reader/features/bookshelf/page/widgets/book_cover.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 书架书籍内容网格。
class BookshelfBookContent extends StatelessWidget {
  final AsyncState<List<BookshelfBook>> asyncBooks;
  final bool batchMode;
  final Set<String> selectedIds;
  final VoidCallback onImportTap;
  final ValueChanged<Set<String>> onSelectionChanged;
  final void Function(BookshelfBook) onBookTap;
  final void Function(BookshelfBook) onBookLongPress;

  const BookshelfBookContent({
    super.key,
    required this.asyncBooks,
    required this.batchMode,
    required this.selectedIds,
    required this.onImportTap,
    required this.onSelectionChanged,
    required this.onBookTap,
    required this.onBookLongPress,
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
    required BookshelfBook book,
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
                begin: 0.05,
                end: 0,
                duration: 400.ms,
                curve: Curves.easeOutCubic,
              )
        : content
              .animate(delay: (index * 80).ms)
              .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic)
              .slideY(
                begin: 0.1,
                end: 0,
                duration: 400.ms,
                curve: Curves.easeOutCubic,
              );

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
    final books = asyncBooks.value ?? [];
    final vm = getIt<BookshelfViewModel>();
    final bool isListView = vm.isListView.value;
    final bool showProgress = vm.showReadingProgress.signal.value;
    if (asyncBooks.isLoading) return const SkeletonGrid();
    if (asyncBooks.hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.loadFailed),
            SizedBox(height: Spacing.sm.value),
            TextButton(
              onPressed: () => vm.loadBooks(),
              child: Text(l10n.retry),
            ),
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
      onRefresh: () async => vm.loadBooks(),
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
                ? _buildListContent(context, theme, l10n, books, showProgress)
                : _buildGridContent(context, theme, l10n, books, showProgress),
          ),
        ),
      ),
    );
  }

  Widget _buildGridContent(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    List<BookshelfBook> books,
    bool showProgress,
  ) {
    final cs = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = LayoutBreakpoints.getGridCrossAxisCount(
          constraints.maxWidth,
        );
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
                    progress: showProgress ? book.progress : null,
                  ),
                  if (batchMode)
                    Positioned(
                      top: 4,
                      right: 4,
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
      },
    );
  }

  Widget _buildListContent(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
    List<BookshelfBook> books,
    bool showProgress,
  ) {
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
        final progress = showProgress ? book.progress : null;
        return _buildBookItemWrapper(
          index: index,
          book: book,
          selected: selected,
          outerPadding: EdgeInsets.only(
            left: 4,
            right: 4,
            bottom: index < books.length - 1 ? 8 : 0,
          ),
          inkWellBorderRadius: BorderRadius.circular(RadiusSize.lg.value),
          selectedBackgroundColor: cs.primaryContainer.withValues(alpha: 0.15),
          slideFromRight: true,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          RadiusSize.sm.value,
                        ),
                        boxShadow: const [DesignTokens.cardShadow],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          RadiusSize.sm.value,
                        ),
                        child: SizedBox(
                          width: 100,
                          height: 150,
                          child: book.coverPath != null
                              ? Image.file(
                                  File(resolveCoverPath(book.coverPath!)!),
                                  fit: BoxFit.cover,
                                  width: 100,
                                  height: 150,
                                  cacheWidth: 200,
                                  errorBuilder: (_, _, _) => Container(
                                    color: cs.primaryContainer.withValues(
                                      alpha: 0.5,
                                    ),
                                    child: Center(
                                      child: Icon(
                                        PhosphorIconsRegular.book,
                                        size: 28,
                                        color: cs.primary.withValues(
                                          alpha: 0.35,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : Container(
                                  color: cs.primaryContainer.withValues(
                                    alpha: 0.5,
                                  ),
                                  child: Center(
                                    child: Icon(
                                      PhosphorIconsRegular.book,
                                      size: 28,
                                      color: cs.primary.withValues(alpha: 0.35),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    SizedBox(width: Spacing.lg.value),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                          SizedBox(height: Spacing.xs.value),
                          Text(
                            book.author ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          SizedBox(height: Spacing.sm.value),
                          Row(
                            children: [
                              _ProgressIndicator(progress: progress),
                              SizedBox(width: Spacing.sm.value),
                              if (book.chapterCount > 0)
                                Text(
                                  '${book.chapterCount}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!batchMode)
                      PopupMenuButton<String>(
                        icon: Icon(
                          PhosphorIconsRegular.dotsThreeVertical,
                          size: IconSize.inline,
                          color: cs.onSurfaceVariant,
                        ),
                        onSelected: (value) {
                          if (value == 'delete') {
                            getIt<BookshelfViewModel>().deleteBook(book.bookId);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  PhosphorIconsRegular.trash,
                                  size: 16,
                                  color: cs.error,
                                ),
                                const SizedBox(width: 8),
                                Text(l10n.deleteBook),
                              ],
                            ),
                          ),
                        ],
                      ),
                    if (batchMode)
                      Checkbox(
                        value: selected,
                        onChanged: (_) {
                          if (selected) {
                            onSelectionChanged(
                              selectedIds
                                  .where((id) => id != book.bookId)
                                  .toSet(),
                            );
                          } else {
                            onSelectionChanged({...selectedIds, book.bookId});
                          }
                        },
                      ),
                  ],
                ),
              ),
              if (batchMode && selected)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(RadiusSize.lg.value),
                        bottomLeft: Radius.circular(RadiusSize.lg.value),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ProgressIndicator extends StatelessWidget {
  final double? progress;
  const _ProgressIndicator({this.progress});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (progress == null) return const SizedBox.shrink();
    return SizedBox(
      width: 60,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress!),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(
                value >= 1.0 ? cs.tertiary : DesignTokens.warmAccent,
              ),
            ),
          );
        },
      ),
    );
  }
}
