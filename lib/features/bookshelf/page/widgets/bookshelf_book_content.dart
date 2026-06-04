import 'dart:io';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zephyr_reader/core/presentation/widgets/skeleton_widget.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:zephyr_reader/core/utils/cover_utils.dart';
import 'package:zephyr_reader/core/utils/adaptive_scroll_physics.dart';
import 'package:zephyr_reader/core/utils/haptic.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

// ─── Bottom-Left Triangle Clipper ──────────────────────────────────────────

class _BottomLeftTriangleClipper extends CustomClipper<Path> {
  const _BottomLeftTriangleClipper();

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.38)
      ..lineTo(size.width * 0.42, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ─── Book Cover ─────────────────────────────────────────────────────────────

class _BookCover extends StatelessWidget {
  final Book book;
  final String statusLabel;
  final double? progress;

  const _BookCover({
    required this.book,
    required this.statusLabel,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final showProgress = progress != null && progress! > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            children: [
              // Cover image / placeholder
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
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
                          File(resolveCoverPath(book.coverPath!)!),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          cacheWidth: 160,
                          errorBuilder: (_, _, _) => Center(
                            child: Icon(
                              PhosphorIconsRegular.book,
                              size: 24,
                              color: cs.primary.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Icon(
                          PhosphorIconsRegular.book,
                          size: 24,
                          color: cs.primary.withValues(alpha: 0.4),
                        ),
                      ),
              ),

              // Status tag - top-right
              if (book.status == BookStatus.reading)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 10,
                        color: cs.onPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

              // Progress triangle overlay - bottom-left
              if (showProgress)
                Positioned.fill(
                  child: ClipPath(
                    clipper: const _BottomLeftTriangleClipper(),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.55),
                    ),
                  ),
                ),

              // Progress percentage text
              if (showProgress)
                Positioned(
                  left: 7,
                  bottom: 7,
                  child: Text(
                    '${(progress! * 100).round()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),

              // Progress bar at bottom
              if (showProgress)
                Positioned(
                  left: 4,
                  right: 4,
                  bottom: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(1.5),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.black.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                      minHeight: 3,
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
            color: cs.onSurface,
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
            childAspectRatio: 0.62,
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
                    hapticFeedback(HapticType.medium);
                    onBookLongPress(book);
                  }
                },
                child:
                    Stack(
                          children: [
                            _BookCover(
                              book: book,
                              statusLabel: _statusLabel(book.status.name),
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
