import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/local/rust_storage_service.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

@injectable
class ProfileViewModel {
  final RustStorageService _storage;

  final vocabStats = asyncSignal<VocabStats?>(AsyncState.loading());
  final globalStats = asyncSignal<GlobalStats?>(AsyncState.loading());

  ProfileViewModel(this._storage);

  Future<void> loadStats() async {
    try {
      final results = await Future.wait([
        _storage.getGlobalReadingStats(),
        _storage.getVocabularyStats(),
      ]);
      globalStats.value = AsyncState.data(results[0] as GlobalStats?);
      vocabStats.value = AsyncState.data(results[1] as VocabStats?);
    } catch (e) {
      globalStats.value = AsyncState.error(e);
      vocabStats.value = AsyncState.error(e);
    }
  }
}
