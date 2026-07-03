import 'package:zephyr_reader/core/utils/logging.dart';
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
/// 提供全局多源搜索（书籍+笔记+生词），结果聚合供给 UI。
@lazySingleton
class SearchViewModel {
  final isSearching = signal(false);

  /// 全量搜索结果（已聚合，直接供给 UI）
  final searchResults = asyncSignal<SearchResults?>(AsyncState.loading());
  final hasSearched = signal<bool>(false);
  final searchError = signal<String?>(null);

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
      ).catchError((Object e, StackTrace stack) {
        Logging.error('searchAllBooks failed', exception: e, stackTrace: stack);
        return <SearchResult>[];
      });
      final noteFuture = note_api
          .searchNotes(query: query)
          .catchError((Object e, StackTrace stack) {
        Logging.error('searchNotes failed', exception: e, stackTrace: stack);
        return <Note>[];
      });

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

  void clear() {
    batch(() {
      searchResults.value = AsyncState.loading();
      hasSearched.value = false;
      searchError.value = null;
    });
  }

  void dispose() {
    isSearching.dispose();
    searchResults.dispose();
    hasSearched.dispose();
    searchError.dispose();
  }
}
