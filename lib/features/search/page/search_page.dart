import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/features/search/application/search_view_model.dart';
import 'package:zephyr_reader/features/search/application/services/search_history_service.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

// ──────────────────────── Internal Models ────────────────────────

class _BookSearchItem {
  final Book book;
  final String? snippet;
  final String? chapterTitle;
  _BookSearchItem({required this.book, this.snippet, this.chapterTitle});
}

class _NoteSearchItem {
  final Note note;
  final Book book;
  _NoteSearchItem({required this.note, required this.book});
}

class _VocabSearchItem {
  final Vocab vocab;
  final String? bookTitle;
  _VocabSearchItem({required this.vocab, this.bookTitle});
}

class _SearchResults {
  final List<_BookSearchItem> books;
  final List<_NoteSearchItem> notes;
  final List<_VocabSearchItem> vocab;
  final int durationMs;
  _SearchResults({
    required this.books,
    required this.notes,
    required this.vocab,
    required this.durationMs,
  });
  int get totalCount => books.length + notes.length + vocab.length;
}

// ──────────────────────── Page ────────────────────────

class SearchPage extends HookWidget {
  final SearchViewModel vm;

  const SearchPage({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = useTextEditingController();
    final focusNode = useFocusNode();
    final history = useMemoized(() => SearchHistoryService());
    final debounceTimer = useRef<Timer?>(null);
    final searchText = useSignal('');

    // VM signal bindings
    final isSearching = useSignalValue<bool, Signal<bool>>(vm.isSearching);
    final hasSearched = useSignalValue<bool, Signal<bool>>(vm.hasSearched);
    final searchError = useSignalValue<String?, Signal<String?>>(
      vm.searchError,
    );

    // Derived search results from VM raw signals
    final searchResults = useComputed(() {
      if (!vm.hasSearched.value) return null;
      if (vm.searchError.value != null) return null;

      final bookMap = vm.allBooksMap.value;
      final allBooksList = vm.allBooks.value;

      final seenBooks = <String>{};
      final bookItems = <_BookSearchItem>[];

      for (final hit in vm.contentHits.value) {
        final book = bookMap[hit.bookId];
        if (book == null || !seenBooks.add(hit.bookId)) continue;
        bookItems.add(
          _BookSearchItem(
            book: book,
            snippet: hit.snippet,
            chapterTitle: hit.chapterTitle,
          ),
        );
      }
      for (final book in vm.titleHits.value) {
        if (seenBooks.add(book.bookId)) {
          bookItems.add(_BookSearchItem(book: book));
        }
      }

      final noteItems = vm.noteHits.value.map((note) {
        final book =
            bookMap[note.bookId] ??
            allBooksList.firstWhere((b) => b.bookId == note.bookId);
        return _NoteSearchItem(note: note, book: book);
      }).toList();

      final vocabItems = vm.vocabHits.value
          .map(
            (v) => _VocabSearchItem(
              vocab: v,
              bookTitle: v.bookId != null ? bookMap[v.bookId]?.title : null,
            ),
          )
          .toList();

      return _SearchResults(
        books: bookItems,
        notes: noteItems,
        vocab: vocabItems,
        durationMs: vm.durationMs.value,
      );
    });

    // Debounced search effect
    useEffect(() {
      void onTextChanged() {
        searchText.value = controller.text;
        debounceTimer.value?.cancel();
        final text = controller.text;
        if (text.trim().isEmpty) {
          vm.clear();
          return;
        }
        debounceTimer.value = Timer(const Duration(milliseconds: 300), () {
          vm.doFullSearch(text.trim());
          history.addHistory(text.trim());
        });
      }

      controller.addListener(onTextChanged);
      return () {
        controller.removeListener(onTextChanged);
        debounceTimer.value?.cancel();
      };
    }, []);

    // Autofocus
    useEffect(() {
      focusNode.requestFocus();
      return null;
    }, []);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchHeader(
              context,
              theme,
              controller,
              focusNode,
              searchText.value,
              vm,
              history,
              onClear: () {
                controller.clear();
                debounceTimer.value?.cancel();
                vm.clear();
              },
              onSearch: (value) {
                debounceTimer.value?.cancel();
                vm.doFullSearch(value);
                history.addHistory(value);
              },
            ),
            if (hasSearched && searchResults.value != null)
              _buildSummaryBar(theme, searchResults.value!),
            Expanded(
              child: _buildBody(
                context,
                theme,
                isSearching,
                hasSearched,
                searchError,
                searchResults.value,
                history,
                controller,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────── Search Header ────────────────

  Widget _buildSearchHeader(
    BuildContext context,
    ThemeData theme,
    TextEditingController controller,
    FocusNode focusNode,
    String currentText,
    SearchViewModel vm,
    SearchHistoryService history, {
    required VoidCallback onClear,
    required ValueChanged<String> onSearch,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '搜索书籍、笔记、生词...',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 8),
                    child: Icon(
                      PhosphorIconsRegular.magnifyingGlass,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  suffixIcon: currentText.isNotEmpty
                      ? IconButton(
                          icon: const Icon(PhosphorIconsRegular.x, size: 16),
                          onPressed: onClear,
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                style: theme.textTheme.bodyLarge,
                textInputAction: TextInputAction.search,
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    onSearch(value.trim());
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => context.pop(),
            child: Text(
              '取消',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────── Summary Bar ────────────────

  Widget _buildSummaryBar(ThemeData theme, _SearchResults results) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(
        '找到 ${results.totalCount} 条结果 · 耗时 ${results.durationMs}ms',
        style: theme.textTheme.labelLarge,
      ),
    );
  }

  // ──────────────── Body ────────────────

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    bool isLoading,
    bool hasSearched,
    String? error,
    _SearchResults? results,
    SearchHistoryService history,
    TextEditingController controller,
  ) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIconsRegular.warningCircle,
              size: 40,
              color: theme.colorScheme.error.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              '搜索出错',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => vm.doFullSearch(controller.text.trim()),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (results != null && results.totalCount == 0) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 4),
            Text(
              '试试其他关键词',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.6,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (results != null) {
      return _buildResultsList(context, theme, results, controller.text.trim());
    }

    return _buildHistorySection(context, theme, history, controller, vm);
  }

  // ──────────────── Results List ────────────────

  Widget _buildResultsList(
    BuildContext context,
    ThemeData theme,
    _SearchResults results,
    String query,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        if (results.books.isNotEmpty)
          _buildBookGroup(context, theme, results.books, query),
        if (results.notes.isNotEmpty)
          _buildNoteGroup(context, theme, results.notes, query),
        if (results.vocab.isNotEmpty)
          _buildVocabGroup(theme, results.vocab, query),
        if (results.totalCount == 0)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    PhosphorIconsRegular.magnifyingGlass,
                    size: 40,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.3,
                    ),
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

  // ──────────────── Book Group ────────────────

  Widget _buildBookGroup(
    BuildContext context,
    ThemeData theme,
    List<_BookSearchItem> items,
    String query,
  ) {
    return _ResultGroup(
      icon: PhosphorIconsRegular.books,
      title: '书籍',
      count: items.length,
      children: items
          .map((item) => _buildBookCard(context, theme, item, query))
          .toList(),
    );
  }

  Widget _buildBookCard(
    BuildContext context,
    ThemeData theme,
    _BookSearchItem item,
    String query,
  ) {
    final book = item.book;
    return GestureDetector(
      onTap: () => context.pushNamed(
        RouteNames.reader,
        pathParameters: {'bookId': book.bookId, 'chapterId': '0'},
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
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
                          File(book.coverPath!),
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
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.4,
                          ),
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
                      '${book.author ?? '未知作者'} · ${book.format.name.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (item.snippet != null) ...[
                      const SizedBox(height: 6),
                      _buildHighlightedSnippet(theme, item.snippet!, query),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  // ──────────────── Note Group ────────────────

  Widget _buildNoteGroup(
    BuildContext context,
    ThemeData theme,
    List<_NoteSearchItem> items,
    String query,
  ) {
    return _ResultGroup(
      icon: PhosphorIconsRegular.notePencil,
      title: '笔记',
      count: items.length,
      children: items
          .map((item) => _buildNoteCard(context, theme, item, query))
          .toList(),
    );
  }

  Widget _buildNoteCard(
    BuildContext context,
    ThemeData theme,
    _NoteSearchItem item,
    String query,
  ) {
    final note = item.note;
    return GestureDetector(
      onTap: () {
        context.pushNamed(
          RouteNames.reader,
          pathParameters: {
            'bookId': note.bookId,
            'chapterId': '${note.chapterIndex}',
          },
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: const Border(
            left: BorderSide(color: Color(0xFFFFA726), width: 3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
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
            _buildHighlightedSnippet(theme, note.content, query),
            const SizedBox(height: 6),
            Text(
              '${item.book.title} · Ch.${note.chapterIndex + 1}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────── Vocab Group ────────────────

  Widget _buildVocabGroup(
    ThemeData theme,
    List<_VocabSearchItem> items,
    String query,
  ) {
    return _ResultGroup(
      icon: PhosphorIconsRegular.bookmarkSimple,
      title: '生词',
      count: items.length,
      children: items
          .map((item) => _buildVocabCard(theme, item, query))
          .toList(),
    );
  }

  Widget _buildVocabCard(ThemeData theme, _VocabSearchItem item, String query) {
    final v = item.vocab;
    return GestureDetector(
      onTap: () {},
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6),
              decoration: const BoxDecoration(
                color: Color(0xFFAB47BC),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHighlightedSnippet(theme, v.word, query),
                  const SizedBox(height: 3),
                  Text(
                    v.translation,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                  if (item.bookTitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.bookTitle!,
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
      ),
    );
  }

  // ──────────────── Snippet Highlighting ────────────────

  Widget _buildHighlightedSnippet(ThemeData theme, String text, String query) {
    if (query.isEmpty) {
      return Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
          height: 1.4,
        ),
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <InlineSpan>[];
    int lastEnd = 0;

    int startIndex = 0;
    while (true) {
      final idx = lowerText.indexOf(lowerQuery, startIndex);
      if (idx == -1) break;
      if (idx > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, idx)));
      }
      spans.add(
        TextSpan(
          text: text.substring(idx, idx + query.length),
          style: TextStyle(
            backgroundColor: Colors.yellow.withValues(alpha: 0.4),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      lastEnd = idx + query.length;
      startIndex = idx + 1;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface,
          height: 1.4,
        ),
        children: spans,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  // ──────────────── History Section ────────────────

  Widget _buildHistorySection(
    BuildContext context,
    ThemeData theme,
    SearchHistoryService history,
    TextEditingController controller,
    SearchViewModel vm,
  ) {
    final historyList = history.getHistory();
    if (historyList.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIconsRegular.magnifyingGlass,
              size: 40,
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              '搜索书籍、笔记、生词',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '搜索历史',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              GestureDetector(
                onTap: history.clearHistory,
                child: Text(
                  '清除',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: historyList.map((h) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: () {
                    controller.text = h;
                    controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: h.length),
                    );
                    vm.doFullSearch(h);
                  },
                  child: Text(h, style: theme.textTheme.bodyMedium),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────── Result Group Widget ────────────────────────

class _ResultGroup extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final List<Widget> children;

  const _ResultGroup({
    required this.icon,
    required this.title,
    required this.count,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
