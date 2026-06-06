import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/async_utils.dart';
import 'package:zephyr_reader/src/rust/api/data/stats.dart' as stats_api;
import 'package:zephyr_reader/src/rust/api/data/vocabulary.dart' as vocab_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

class ProfileViewModel {
  final vocabStats = asyncSignal<VocabStats?>(AsyncState.loading());
  final globalStats = asyncSignal<GlobalStats?>(AsyncState.loading());

  ProfileViewModel();

  /// 加载全局阅读统计和生词统计。
  Future<void> loadStats() async {
    await Future.wait([
      globalStats.loadAsync(
        () => stats_api.getGlobalReadingStats(),
        label: 'globalStats',
      ),
      vocabStats.loadAsync(
        () => vocab_api.getVocabularyStats(),
        label: 'vocabStats',
      ),
    ]);
  }

  /// 释放所有 signal 资源。
  void dispose() {
    vocabStats.dispose();
    globalStats.dispose();
  }
}
