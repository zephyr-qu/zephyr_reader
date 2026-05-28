library;

import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:signals/signals.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/api/data/vocabulary.dart' as vocab_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

@injectable
class VocabularyViewModel {
  final words = asyncSignal<List<Vocab>>(AsyncState.data([]));
  final stats = signal<VocabStats?>(null);
  final filterStatus = signal<VocabStatus?>(VocabStatus.new_);
  final filterWordList = signal<String?>(null);
  final searchQuery = signal<String>('');

  /// bookId -> bookTitle lookup map
  final bookTitles = signal<Map<String, String>>({});

  VocabularyViewModel();

  Future<void> loadWords({String? bookId}) async {
    words.value = AsyncState.loading();
    try {
      final results = await Future.wait([
        vocab_api.listVocabularyByStatus(
          bookId: bookId,
          status: filterStatus.value,
          wordList: filterWordList.value,
        ),
        vocab_api.getVocabularyStats(),
      ]);
      final loadedWords = results[0] as List<Vocab>;
      words.value = AsyncState.data(loadedWords);

      final s = results[1] as VocabStats;
      stats.value = s;
    } catch (e) {
      words.value = AsyncState.error(e, StackTrace.current);
    }
    unawaited(_loadBookTitles());
  }

  Future<void> _loadBookTitles() async {
    try {
      final allBooks = await book_api.listBooks();
      final map = <String, String>{};
      for (final book in allBooks) {
        map[book.bookId] = book.title;
      }
      bookTitles.value = map;
    } catch (e) {
      Logging.error('加载书籍标题失败', exception: e);
    }
  }

  Future<void> refresh() async {
    await loadWords();
  }

  Future<void> setFilter(VocabStatus? status) async {
    filterStatus.value = status;
    await loadWords();
  }

  Future<void> setWordListFilter(String? wordList) async {
    filterWordList.value = wordList;
    await loadWords();
  }

  Future<void> updateStatus(String id, String s) async {
    final status = switch (s) {
      'new' || '' => VocabStatus.new_,
      'learning' => VocabStatus.learning,
      'mastered' => VocabStatus.mastered,
      'ignored' => VocabStatus.ignored,
      _ => VocabStatus.new_,
    };
    await vocab_api.updateVocabularyStatus(id: id, status: status);
    await loadWords();
  }

  Future<void> deleteWord(String id) async {
    await vocab_api.deleteVocabulary(id: id);
    await loadWords();
  }
}
