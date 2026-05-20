library;

import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/features/vocabulary/data/vocabulary_service.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

@injectable
class VocabularyViewModel {
  final VocabularyService _service;

  final words = signal<List<VocabEntry>>([]);
  final stats = signal<VocabStats?>(null);
  final loading = signal<bool>(false);
  final error = signal<String?>(null);
  final filterStatus = signal<String?>('learning');
  final searchQuery = signal<String>('');

  VocabularyViewModel(this._service);

  Future<void> loadWords({String? bookId}) async {
    loading.value = true;
    error.value = null;
    try {
      final results = await Future.wait([
        _service.getWords(bookId: bookId, status: filterStatus.value),
        _service.getStats(),
      ]);
      words.value = results[0] as List<VocabEntry>;
      stats.value = results[1] as VocabStats;
    } catch (e) {
      error.value = '加载失败: $e';
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
