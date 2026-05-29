import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/api/data/note.dart' as note_api;
import 'package:zephyr_reader/src/rust/api/data/vocabulary.dart' as vocab_api;
import 'package:zephyr_reader/src/rust/api/search.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 搜索视图模型
@injectable
class SearchViewModel {
  /// 搜索关键词
  final keyword = signal<String>('');

  /// 搜索结果（FTS5 精确搜索）
  final results = asyncSignal<List<SearchResult>>(AsyncState.data([]));

  /// 是否正在搜索
  final isSearching = signal<bool>(false);

  /// 当前页码
  final currentPage = signal<int>(1);

  /// 是否有更多数据
  final hasMore = signal<bool>(false);

  // ── 全量搜索（多源聚合） ──

  /// 全量搜索结果
  final allBooks = signal<List<Book>>([]);
  final titleHits = signal<List<Book>>([]);
  final contentHits = signal<List<SearchResult>>([]);
  final vocabHits = signal<List<Vocab>>([]);
  final noteHits = signal<List<Note>>([]);
  final allBooksMap = signal<Map<String, Book>>({});
  final durationMs = signal<int>(0);
  final hasSearched = signal<bool>(false);
  final searchError = signal<String?>(null);

  SearchViewModel();

  /// 执行 FTS5 搜索（简单搜索）
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
        limit: currentPage.value,
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

  /// 加载更多
  Future<void> loadMore() async {
    if (!hasMore.value || isSearching.value) return;

    currentPage.value++;
    await searchBook(loadMore: true);
  }

  /// 全量多源搜索（书籍+笔记+生词）
  Future<void> doFullSearch(String query) async {
    isSearching.value = true;
    searchError.value = null;
    hasSearched.value = false;

    final stopwatch = Stopwatch()..start();

    try {
      final allBooksFuture = book_api.listBooks();
      final titleHitsFuture = book_api.searchBooks(keyword: query);
      final vocabHitsFuture = vocab_api.searchVocabularyWords(query: query);

      final allBooksResult = await allBooksFuture;
      final bookMap = {for (final b in allBooksResult) b.bookId: b};

      Future<List<SearchResult>> ftsSearch() async {
        try {
          return await searchAllBooks(query: query, limit: 50, offset: 0);
        } catch (_) {
          return [];
        }
      }

      final results = await Future.wait([
        titleHitsFuture,
        ftsSearch(),
        vocabHitsFuture,
      ]);

      final matchedBooks = results[0] as List<Book>;
      final contentSearchResults = results[1] as List<SearchResult>;
      final vocabList = results[2] as List<Vocab>;

      final noteResults = <Note>[];
      try {
        final notesBatch = await note_api.listNotesByBooks(
          bookIds: allBooksResult.map((b) => b.bookId).toList(),
        );
        final lowerQuery = query.toLowerCase();
        for (final (_, notes) in notesBatch) {
          for (final note in notes) {
            if (note.content.toLowerCase().contains(lowerQuery) ||
                (note.selectedText?.toLowerCase().contains(lowerQuery) ==
                    true)) {
              noteResults.add(note);
            }
          }
        }
      } catch (e) {
        Logging.error('搜索笔记失败', exception: e);
      }

      stopwatch.stop();

      allBooks.value = allBooksResult;
      allBooksMap.value = bookMap;
      titleHits.value = matchedBooks;
      contentHits.value = contentSearchResults;
      vocabHits.value = vocabList;
      noteHits.value = noteResults;
      durationMs.value = stopwatch.elapsedMilliseconds;
      hasSearched.value = true;
    } catch (e) {
      searchError.value = e.toString();
      hasSearched.value = true;
    } finally {
      isSearching.value = false;
    }
  }

  /// 更新搜索关键词
  void updateKeyword(String value) {
    keyword.value = value;
  }

  /// 清空搜索结果
  void clear() {
    keyword.value = '';
    results.value = AsyncState.data([]);
    currentPage.value = 1;
    titleHits.value = [];
    contentHits.value = [];
    vocabHits.value = [];
    noteHits.value = [];
    allBooks.value = [];
    allBooksMap.value = {};
    durationMs.value = 0;
    hasSearched.value = false;
    searchError.value = null;
  }
}
