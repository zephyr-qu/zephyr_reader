import 'package:signals_flutter/signals_flutter.dart';
import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/src/rust/api/data/stats.dart' as rust_stats;
import 'package:zephyr_reader/src/rust/api/data/vocabulary.dart' as rust_vocab;
import 'package:zephyr_reader/src/rust/storage/models.dart';

enum StatisticsPeriod { today, week, month, year }

@injectable
class StatisticsViewModel {
  final selectedPeriod = signal<StatisticsPeriod>(StatisticsPeriod.month);
  final globalStats = signal<GlobalStats?>(null);
  final dailyRecords = signal<List<ReadingStats>>([]);
  final vocabNew = signal(0);
  final vocabLearning = signal(0);
  final vocabMastered = signal(0);
  final vocabIgnored = signal(0);
  final loaded = signal(false);

  StatisticsViewModel() {
    loadData();
  }

  Future<void> loadData({StatisticsPeriod? period}) async {
    if (period != null) selectedPeriod.value = period;
    try {
      final days = switch (selectedPeriod.value) {
        StatisticsPeriod.today => 1,
        StatisticsPeriod.week => 7,
        StatisticsPeriod.month => 30,
        StatisticsPeriod.year => 365,
      };
      final results = await Future.wait([
        rust_stats.getGlobalReadingStats(),
        rust_stats.getReadingStatsByDaysWithFill(days: days),
        rust_vocab.listVocabularyByStatus(status: VocabStatus.new_),
        rust_vocab.listVocabularyByStatus(status: VocabStatus.learning),
        rust_vocab.listVocabularyByStatus(status: VocabStatus.mastered),
        rust_vocab.listVocabularyByStatus(status: VocabStatus.ignored),
      ]);
      globalStats.value = results[0] as GlobalStats;
      dailyRecords.value = results[1] as List<ReadingStats>;
      vocabNew.value = (results[2] as List<Vocab>).length;
      vocabLearning.value = (results[3] as List<Vocab>).length;
      vocabMastered.value = (results[4] as List<Vocab>).length;
      vocabIgnored.value = (results[5] as List<Vocab>).length;
    } catch (e) {
      Logging.error('加载统计数据失败', exception: e);
    } finally {
      loaded.value = true;
    }
  }
}
