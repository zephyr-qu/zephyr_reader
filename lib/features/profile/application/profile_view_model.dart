import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/src/rust/api/data/stats.dart' as stats_api;
import 'package:zephyr_reader/src/rust/api/data/vocabulary.dart' as vocab_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

@injectable
class ProfileViewModel {
  final vocabStats = asyncSignal<VocabStats?>(AsyncState.loading());
  final globalStats = asyncSignal<GlobalStats?>(AsyncState.loading());

  ProfileViewModel();

  Future<void> loadStats() async {
    try {
      final results = await Future.wait([
        stats_api.getGlobalReadingStats(),
        vocab_api.getVocabularyStats(),
      ]);
      globalStats.value = AsyncState.data(results[0] as GlobalStats?);
      vocabStats.value = AsyncState.data(results[1] as VocabStats?);
    } catch (e) {
      globalStats.value = AsyncState.error(e);
      vocabStats.value = AsyncState.error(e);
    }
  }
}
