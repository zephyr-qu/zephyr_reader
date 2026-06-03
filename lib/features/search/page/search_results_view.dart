import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'search_result_cards.dart';
import 'search_result_header.dart';
import 'search_results.dart';

// ──────────────────────── Results List View ────────────────────────

class SearchResultsView extends StatelessWidget {
  final SearchResults results;
  final String query;

  const SearchResultsView({
    super.key,
    required this.results,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        if (results.books.isNotEmpty)
          ResultGroupHeader(
            icon: PhosphorIconsRegular.books,
            title: '书籍',
            count: results.books.length,
            children: results.books
                .map((item) => BookSearchCard(
                      book: item.book,
                      snippet: item.snippet,
                      query: query,
                    ))
                .toList(),
          ),
        if (results.notes.isNotEmpty)
          ResultGroupHeader(
            icon: PhosphorIconsRegular.notePencil,
            title: '笔记',
            count: results.notes.length,
            children: results.notes
                .map((item) => NoteSearchCard(
                      note: item.note,
                      bookTitle: item.book.title,
                      query: query,
                    ))
                .toList(),
          ),
        if (results.vocab.isNotEmpty)
          ResultGroupHeader(
            icon: PhosphorIconsRegular.bookmarkSimple,
            title: '生词',
            count: results.vocab.length,
            children: results.vocab
                .map((item) => VocabSearchCard(
                      vocab: item.vocab,
                      translation: item.vocab.translation,
                      bookTitle: item.bookTitle,
                      query: query,
                    ))
                .toList(),
          ),
        if (results.totalCount == 0)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    PhosphorIconsRegular.magnifyingGlass,
                    size: 40,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '未找到相关结果',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
