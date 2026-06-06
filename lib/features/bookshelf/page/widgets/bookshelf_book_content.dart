import 'package:flutter/material.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zephyr_reader/core/presentation/widgets/skeleton_widget.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zephyr_reader/core/utils/adaptive_scroll_physics.dart';
import 'package:zephyr_reader/core/utils/haptic.dart';
import 'package:zephyr_reader/features/bookshelf/page/widgets/book_cover.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class BookshelfBookContent extends StatelessWidget {
  final bool isLoading;
  final bool hasError;
  final List<Book> books;
  final int crossAxisCount;
  final bool batchMode;
  final Set<String> selectedIds;
  final VoidCallback onRetry;
  final VoidCallback onImportTap;
  final VoidCallback onRefresh;
  final ValueChanged<Set<String>> onSelectionChanged;
  final void Function(Book) onBookTap;
  final void Function(Book) onBookLongPress;
  final Map<String, double> readingProgress;

  const BookshelfBookContent({
    super.key,
    required this.isLoading,
    required this.hasError,
    required this.books,
    required this.crossAxisCount,
    required this.batchMode,
    required this.selectedIds,
    required this.onRetry,
    required this.onImportTap,
    required this.onRefresh,
    required this.onSelectionChanged,
    required this.onBookTap,
    required this.onBookLongPress,
    required this.readingProgress,
  });

  String _statusLabel(BuildContext context, String statusName) {
    final l10n = AppLocalizations.of(context)!;
    return switch (statusName) {
      'reading' => l10n.reading,
      'completed' => l10n.finished,
      _ => l10n.notStarted,
    };
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
            SizedBox(height: DesignTokens.spacing(Spacing.sm)),
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
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            SizedBox(height: DesignTokens.spacing(Spacing.md)),
            Text(
              l10n.bookshelfEmpty,
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: DesignTokens.spacing(Spacing.md)),
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
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          DesignTokens.spacing(Spacing.lg),
          20,
          DesignTokens.spacing(Spacing.lg),
          batchMode ? 80 : 0,
        ),
        child: GridView.builder(
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
            return RepaintBoundary(
              child: InkWell(
                onTap: batchMode
                    ? () {
                        if (selected) {
                          onSelectionChanged(
                            selectedIds
                                .where((id) => id != book.bookId)
                                .toSet(),
                          );
                        } else {
                          onSelectionChanged({...selectedIds, book.bookId});
                        }
                      }
                    : () => onBookTap(book),
                onLongPress: () {
                  if (!batchMode) {
                    hapticFeedback(HapticType.medium);
                    onBookLongPress(book);
                  }
                },
                child:
                    Stack(
                          children: [
                            BookCover(
                              book: book,
                              statusLabel: _statusLabel(
                                context,
                                book.status.name,
                              ),
                              progress: readingProgress[book.bookId],
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
                                      ? theme.colorScheme.primary
                                      : Colors.white.withValues(alpha: 0.6),
                                  size: 22,
                                ),
                              ),
                          ],
                        )
                        .animate(delay: (index * 80).ms)
                        .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic)
                        .slideY(
                          begin: 0.1,
                          end: 0,
                          duration: 400.ms,
                          curve: Curves.easeOutCubic,
                        ),
              ),
            );
          },
        ),
      ),
    );
  }
}
