import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/features/search/page/search_results.dart';
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/api/data/note.dart' as note_api;
import 'package:zephyr_reader/src/rust/api/data/vocabulary.dart' as vocab_api;
import 'package:zephyr_reader/src/rust/api/search.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 搜索功能 ViewModel
///
/// 负责三种搜索：
/// 1. `searchBook()` — 分页搜索书籍全文
/// 2. `loadMore()` — 加载更多分页结果
/// 3. `doFullSearch()` — 全局多源搜索
@lazySingleton
class SearchViewModel {
  final keyword = signal('');
  final isSearching = signal(false);
  final results = asyncSignal<List<SearchResult>>(AsyncState.data([]));
  final currentPage = signal(1);
  final hasMore = signal(false);

  /// 全量搜索结果（已聚合，直接供给 UI）
  final searchResults = asyncSignal<SearchResults?>(AsyncState.loading());

  final hasSearched = signal<bool>(false);
  final searchError = signal<String?>(null);
  final durationMs = signal<int>(0);

  // ============ 分页搜索 ============

  /// 分页搜索书籍全文
  Future<void> searchBook({bool loadMore = false}) async {
    if (keyword.value.isEmpty) {
      results.value = AsyncState.data([]);
      return;
    }

    if (!loadMore) {
      currentPage.value = 1;
    }

    isSearching.value = true;

    try {
      final previous = loadMore
          ? (results.value.value ?? [])
          : <SearchResult>[];
      results.value = AsyncState.loading();

      final data = await searchAllBooks(
        query: keyword.value,
        limit: 20,
        offset: (currentPage.value - 1) * 20,
      );

      if (loadMore) {
        results.value = AsyncState.data([...previous, ...data]);
      } else {
        results.value = AsyncState.data(data);
      }

      hasMore.value = data.length >= 20;
    } catch (e) {
      results.value = AsyncState.error(e);
    } finally {
      isSearching.value = false;
    }
  }

  /// 加载更多结果
  Future<void> loadMore() async {
    if (!hasMore.value || isSearching.value) return;
    currentPage.value++;
    await searchBook(loadMore: true);
  }

  /// 收藏搜索结果到历史
  void deleteFromHistory(int index) {
    final current = results.value.value ?? [];
    if (index < current.length) {
      final updated = [...current]..removeAt(index);
      results.value = AsyncState.data(updated);
    }
  }

  // ============ 全量搜索 ============

  /// 全量多源搜索（书籍+笔记+生词）
  Future<void> doFullSearch(String query) async {
    batch(() {
      isSearching.value = true;
      searchError.value = null;
      hasSearched.value = false;
    });

    final stopwatch = Stopwatch()..start();

    try {
      // 全部搜索并行触发
      final allBooksFuture = book_api.listBooks();
      final titleHitsFuture = book_api.searchBooks(keyword: query);
      final vocabHitsFuture = vocab_api.searchVocabularyWords(query: query);
      final ftsFuture = searchAllBooks(
        query: query,
        limit: 50,
        offset: 0,
      ).catchError((_) => <SearchResult>[]);
      final noteFuture = note_api
          .searchNotes(query: query)
          .catchError((_) => <Note>[]);

      final allBooksResult = await allBooksFuture;
      final bookMap = {for (final b in allBooksResult) b.bookId: b};

      final results = await Future.wait([
        titleHitsFuture,
        ftsFuture,
        vocabHitsFuture,
        noteFuture,
      ]);

      final matchedBooks = results[0] as List<Book>;
      final contentSearchResults = results[1] as List<SearchResult>;
      final vocabList = results[2] as List<Vocab>;
      final noteResults = results[3] as List<Note>;

      // 构造聚合结果（在异步线程完成，不阻塞 UI）
      final seenBooks = <String>{};
      final bookItems = <BookSearchItem>[];

      for (final hit in contentSearchResults) {
        final book = bookMap[hit.bookId];
        if (book == null || !seenBooks.add(hit.bookId)) continue;
        bookItems.add(
          BookSearchItem(
            book: book,
            snippet: hit.snippet,
            chapterTitle: hit.chapterTitle,
          ),
        );
      }
      for (final book in matchedBooks) {
        if (seenBooks.add(book.bookId)) {
          bookItems.add(BookSearchItem(book: book));
        }
      }

      final noteItems = noteResults.map((note) {
        final book =
            bookMap[note.bookId] ??
            allBooksResult.firstWhere((b) => b.bookId == note.bookId);
        return NoteSearchItem(note: note, book: book);
      }).toList();

      final vocabItems = vocabList
          .map(
            (v) => VocabSearchItem(
              vocab: v,
              bookTitle: v.bookId != null ? bookMap[v.bookId]?.title : null,
            ),
          )
          .toList();

      batch(() {
        searchResults.value = AsyncState.data(
          SearchResults(
            books: bookItems,
            notes: noteItems,
            vocab: vocabItems,
            durationMs: stopwatch.elapsedMilliseconds,
          ),
        );
        durationMs.value = stopwatch.elapsedMilliseconds;
        hasSearched.value = true;
      });
    } catch (e) {
      batch(() {
        searchError.value = e.toString();
        searchResults.value = AsyncState.error(e);
        hasSearched.value = true;
      });
    } finally {
      isSearching.value = false;
    }
  }

  /// 更新搜索关键词
  void updateKeyword(String value) {
    keyword.value = value;
  }

  void clear() {
    batch(() {
      keyword.value = '';
      results.value = AsyncState.data([]);
      currentPage.value = 1;
      searchResults.value = AsyncState.loading();
      durationMs.value = 0;
      hasSearched.value = false;
      searchError.value = null;
    });
  }
}
