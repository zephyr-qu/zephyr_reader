import 'dart:async';

import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/shared/book_title_resolver.dart';
import 'package:zephyr_reader/src/rust/api/data/vocabulary.dart' as vocab_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';


class VocabularyViewModel {
  final words = asyncSignal<List<Vocab>>(AsyncState.data([]));
  final stats = signal<VocabStats?>(null);
  final filterStatus = signal<VocabStatus?>(VocabStatus.unstarted);
  final filterWordList = signal<String?>(null);
  final searchQuery = signal<String>('');

  /// bookId -> bookTitle lookup map
  final bookTitles = signal<Map<String, String>>({});

  Future<void> loadWords({bool showLoading = true}) async {
    if (showLoading) {
      words.value = AsyncState.loading();
    }
    try {
      final results = await Future.wait([
        vocab_api.listVocabularyByStatus(
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
    bookTitles.value = await loadBookTitles();
  }

  Future<void> refresh() async {
    await loadWords();
  }

  Future<void> setFilter(VocabStatus? status) async {
    filterStatus.value = status;
    await loadWords(showLoading: false);
  }

  Future<void> setWordListFilter(String? wordList) async {
    filterWordList.value = wordList;
    await loadWords(showLoading: false);
  }

  Future<void> updateStatus(String id, VocabStatus status) async {
    await vocab_api.updateVocabularyStatus(id: id, status: status);
    await loadWords();
  }

  Future<void> deleteWord(String id) async {
    await vocab_api.deleteVocabulary(id: id);
    await loadWords();
  }
 
  void dispose() {
    words.dispose();
    stats.dispose();
    filterStatus.dispose();
    filterWordList.dispose();
    searchQuery.dispose();
    bookTitles.dispose();
  }
}
