import 'package:zephyr_reader/src/rust/domain/book/models.dart';
import 'package:zephyr_reader/src/rust/domain/category/models.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:zephyr_reader/features/bookshelf/page/widgets/book_cover.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

import 'package:zephyr_reader/core/utils/cover_utils.dart';

/// 封面 + 元数据（标题/作者/分类标签/文件信息）
class BookDetailHero extends StatelessWidget {
  final Book book;
  final List<Category> categories;
  const BookDetailHero({
    super.key,
    required this.book,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 120,
              height: 180,
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    color: theme.colorScheme.primaryContainer,
                    child: book.coverPath != null
                        ? Image.file(
                            File(resolveCoverPath(book.coverPath!)!),
                            fit: BoxFit.cover,
                            cacheWidth: 240,
                            errorBuilder: (_, _, _) => _coverPlaceholder(theme),
                          )
                        : _coverPlaceholder(theme),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Meta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    text: book.author ?? l10n.unknownAuthor,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    children: [
                      if (book.translator != null &&
                          book.translator!.isNotEmpty)
                        TextSpan(
                          text: ' · 译 ${book.translator}',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.7),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Tags
                if (categories.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: categories
                        .map(
                          (c) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer
                                  .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              c.name,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                // Description preview
                if (book.description != null && book.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      book.description!,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverPlaceholder(ThemeData theme) {
    return BookCover.placeholder(theme.colorScheme, size: 48);
  }
}
