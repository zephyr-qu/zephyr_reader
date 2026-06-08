import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/core/utils/cover_utils.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

import 'search_highlight.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// 书籍搜索结果卡片列表。
///
/// 展示搜索到的书籍条目，每个卡片显示封面、标题和匹配片段。
// ──────────────────── Shared Card Shell ────────────────────

/// 搜索结果卡片共用容器（圆角 + 阴影 + 底部边距 + 水波纹）
class SearchCard extends StatelessWidget {
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final BoxBorder? border;
  final Widget child;

  const SearchCard({
    super.key,
    this.onTap,
    this.padding,
    this.border,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: border,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ──────────────────────── Book Card ────────────────────────

class BookSearchCard extends StatelessWidget {
  final Book book;
  final String? snippet;
  final String query;

  const BookSearchCard({
    super.key,
    required this.book,
    this.snippet,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return SearchCard(
      onTap: () => context.pushNamed(
        RouteNames.reader,
        pathParameters: {'bookId': book.bookId, 'chapterId': '0'},
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(12),
            ),
            child: SizedBox(
              width: 40,
              height: 56,
              child: Container(
                color: theme.colorScheme.primaryContainer,
                child: book.coverPath != null
                    ? Image.file(
                        File(resolveCoverPath(book.coverPath!)!),
                        fit: BoxFit.cover,
                        cacheWidth: 80,
                        errorBuilder: (_, _, _) => Icon(
                          PhosphorIconsRegular.book,
                          size: 20,
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      )
                    : Icon(
                        PhosphorIconsRegular.book,
                        size: 20,
                        color: theme.colorScheme.primary.withValues(alpha: 0.4),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${book.author ?? l10n.unknownAuthor} · ${book.format.name.toUpperCase()}',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (snippet != null) ...[
                    const SizedBox(height: 6),
                    buildHighlightedSnippet(theme, snippet!, query),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ──────────────────────── Note Card ────────────────────────

class NoteSearchCard extends StatelessWidget {
  final Note note;
  final String bookTitle;
  final String query;

  const NoteSearchCard({
    super.key,
    required this.note,
    required this.bookTitle,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return SearchCard(
      onTap: () {
        context.pushNamed(
          RouteNames.reader,
          pathParameters: {
            'bookId': note.bookId,
            'chapterId': '${note.chapterIndex}',
          },
        );
      },
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      border: const Border(
        left: BorderSide(color: Color(0xFFFFA726), width: 3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (note.selectedText != null && note.selectedText!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                note.selectedText!,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          buildHighlightedSnippet(theme, note.content, query),
          const SizedBox(height: 6),
          Text(
            '$bookTitle · ${l10n.chapterN(note.chapterIndex + 1)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────── Vocab Card ────────────────────────

class VocabSearchCard extends StatelessWidget {
  final Vocab vocab;
  final String translation;
  final String? bookTitle;
  final String query;

  const VocabSearchCard({
    super.key,
    required this.vocab,
    required this.translation,
    this.bookTitle,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SearchCard(
      onTap: () {
        if (vocab.bookId != null && vocab.chapterIndex != null) {
          context.pushNamed(
            RouteNames.reader,
            pathParameters: {
              'bookId': vocab.bookId!,
              'chapterId': '${vocab.chapterIndex}',
            },
          );
        } else {
          context.pushNamed(RouteNames.vocabulary);
        }
      },
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildHighlightedSnippet(theme, vocab.word, query),
                const SizedBox(height: 3),
                Text(
                  translation,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
                if (bookTitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    bookTitle!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
