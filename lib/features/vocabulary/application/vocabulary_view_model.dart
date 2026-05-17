library;

import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/features/vocabulary/data/vocabulary_service.dart';
import 'package:zephyr_reader/src/rust/api/vocabulary.dart' as vocab_api;

@injectable
class VocabularyViewModel {
  final VocabularyService _service;

  final words = signal<List<vocab_api.VocabEntry>>([]);
  final stats = signal<vocab_api.VocabStats?>(null);
  final loading = signal<bool>(false);
  final filterStatus = signal<String?>('learning');
  final searchQuery = signal<String>('');

  VocabularyViewModel(this._service);

  Future<void> loadWords({String? bookId}) async {
    loading.value = true;
    try {
      final results = await Future.wait([
        _service.getWords(bookId: bookId, status: filterStatus.value),
        _service.getStats(),
      ]);
      words.value = results[0] as List<vocab_api.VocabEntry>;
      stats.value = results[1] as vocab_api.VocabStats;
    } finally {
      loading.value = false;
    }
  }

  Future<void> refresh() async {
    await loadWords();
  }

  Future<void> setFilter(String? status) async {
    filterStatus.value = status;
    await loadWords();
  }

  Future<void> updateStatus(String id, String status) async {
    await _service.updateStatus(id, status);
    await loadWords();
  }

  Future<void> deleteWord(String id) async {
    await _service.delete(id);
    await loadWords();
  }
}
