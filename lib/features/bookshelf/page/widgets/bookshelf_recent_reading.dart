import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class _RecentBookCard extends StatelessWidget {
  final Book book;
  final double? progress;
  final VoidCallback onTap;

  const _RecentBookCard({
    required this.book,
    this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
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
                              cacheWidth: 80,
                              errorBuilder: (_, _, _) => Center(
                                child: Icon(
                                  PhosphorIconsRegular.book,
                                  size: 20,
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
                              size: 20,
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                  ),
                  if (book.status == BookStatus.reading &&
                      progress != null &&
                      progress! > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ClipRRect(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(
                            DesignTokens.radius(RadiusSize.sm),
                          ),
                          bottomRight: Radius.circular(
                            DesignTokens.radius(RadiusSize.sm),
                          ),
                        ),
                        child: LinearProgressIndicator(
                          value: progress!.clamp(0.0, 1.0),
                          minHeight: 2,
                          backgroundColor:
                              Colors.black.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation(
                            theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BookshelfRecentReading extends StatelessWidget {
  final List<Book> recentBooks;
  final bool showSection;
  final Map<String, double> readingProgress;

  const BookshelfRecentReading({
    super.key,
    required this.recentBooks,
    required this.showSection,
    required this.readingProgress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (recentBooks.isEmpty || !showSection) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        DesignTokens.spacing(Spacing.lg),
        8,
        DesignTokens.spacing(Spacing.lg),
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                PhosphorIconsRegular.clockClockwise,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                '最近阅读',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: recentBooks.length,
              separatorBuilder: (_, _) =>
                  SizedBox(width: DesignTokens.spacing(Spacing.sm)),
              itemBuilder: (context, index) {
                final book = recentBooks[index];
                return _RecentBookCard(
                  book: book,
                  progress: readingProgress[book.bookId],
                  onTap: () {
                    context.pushNamed(
                      RouteNames.reader,
                      pathParameters: {
                        'bookId': book.bookId,
                        'chapterId': '0',
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
