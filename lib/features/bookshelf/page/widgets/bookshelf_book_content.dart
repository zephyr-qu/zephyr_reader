import 'dart:io';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zephyr_reader/core/presentation/widgets/skeleton_widget.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/utils/adaptive_scroll_physics.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class _BookCover extends StatelessWidget {
  final Book book;
  final String statusLabel;

  const _BookCover({required this.book, required this.statusLabel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(
                    DesignTokens.radius(RadiusSize.sm),
                  ),
                ),
                child: book.coverPath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(
                          DesignTokens.radius(RadiusSize.sm),
                        ),
                        child: Image.file(
                          File(book.coverPath!),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          cacheWidth: 160,
                          errorBuilder: (_, _, _) => Center(
                            child: Icon(
                              PhosphorIconsRegular.book,
                              size: 24,
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Icon(
                          PhosphorIconsRegular.book,
                          size: 24,
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ),
              ),
              if (book.status == BookStatus.reading)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          book.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

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
  });

  String _statusLabel(String statusName) {
    return switch (statusName) {
      'reading' => '阅读中',
      'completed' => '已读完',
      _ => '未开始',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) return const SkeletonGrid();
    if (hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '加载失败',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            SizedBox(height: DesignTokens.spacing(Spacing.sm)),
            TextButton(onPressed: onRetry, child: const Text('重试')),
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
              '书架空空如也',
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: DesignTokens.spacing(Spacing.md)),
            FilledButton.tonalIcon(
              onPressed: onImportTap,
              icon: const Icon(PhosphorIconsRegular.uploadSimple, size: 18),
              label: const Text('导入书籍'),
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
            childAspectRatio: 0.55,
            crossAxisSpacing: 14,
            mainAxisSpacing: 18,
          ),
          itemCount: books.length,
          itemBuilder: (context, index) {
            final book = books[index];
            final selected = selectedIds.contains(book.bookId);
            return RepaintBoundary(
              child: GestureDetector(
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
                    onBookLongPress(book);
                  }
                },
                child: Stack(
                  children: [
                    _BookCover(
                      book: book,
                      statusLabel: _statusLabel(book.status.name),
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
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
