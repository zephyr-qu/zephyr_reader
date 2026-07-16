import 'package:zephyr_reader/src/rust/domain/book/models.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/utils/cover_utils.dart';


/// 最近阅读书籍卡片。
///
/// 展示书籍封面和标题，点击跳转到阅读器。
class HomeRecentBookCard extends StatelessWidget {
  final Book book;

  const HomeRecentBookCard({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.pushNamed(
        AppRoute.reader.name,
        pathParameters: {'bookId': book.bookId, 'chapterId': '0'},
      ),
      borderRadius: BorderRadius.circular(RadiusSize.sm.value),
      child: SizedBox(
        width: 72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(RadiusSize.sm.value),
              child: SizedBox(
                width: 72,
                height: 96,
                child: book.coverPath != null
                    ? Image.file(
                        File(resolveCoverPath(book.coverPath!)!),
                        fit: BoxFit.cover,
                        cacheWidth: 144,
                        errorBuilder: (_, _, _) => Container(
                          color: theme.colorScheme.primaryContainer,
                          child: Icon(
                            PhosphorIconsRegular.bookOpenText,
                            size: 24,
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        color: theme.colorScheme.primaryContainer,
                        child: Icon(
                          PhosphorIconsRegular.bookOpenText,
                          size: 24,
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ),
              ),
            ),
            SizedBox(height: Spacing.sm.value),
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.3,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
