import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/api/data/vocabulary.dart' as vocab_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

class VocabularyViewModel {
  final words = asyncSignal<List<Vocab>>(AsyncState.data([]));
  final stats = asyncSignal<VocabStats?>(AsyncState.loading());
  final filterStatus = signal<VocabStatus?>(VocabStatus.unstarted);
  final filterWordList = signal<String?>(null);
  final wordLists = asyncSignal<List<String>>(AsyncState.loading());
  final bookTitles = asyncSignal<Map<String, String>>(AsyncState.loading());

  /// 加载生词列表、生词统计和书籍标题，支持是否显示加载态。
  Future<void> loadWords() async {
    try {
      final results = await Future.wait([
        vocab_api.listVocabularyByStatus(
          status: filterStatus.value,
          wordList: filterWordList.value,
        ),
        vocab_api.getVocabularyStats(),
        book_api.mapBookTitles(),
        vocab_api.listWordLists(),
      ]);
      words.value = AsyncState.data(results[0] as List<Vocab>);
      stats.value = AsyncState.data(results[1] as VocabStats);
      bookTitles.value = AsyncState.data(results[2] as Map<String, String>);
      wordLists.value = AsyncState.data(results[3] as List<String>);
    } catch (e) {
      words.value = AsyncState.error(e);
      stats.value = AsyncState.error(e);
      bookTitles.value = AsyncState.error(e);
      wordLists.value = AsyncState.error(e);
    }
  }

  /// 刷新生词列表。
  Future<void> refresh() async {
    await loadWords();
  }

  /// 按学习状态筛选生词。
  Future<void> setFilter(VocabStatus? status) async {
    filterStatus.value = status;
    await loadWords();
  }

  /// 按词库筛选生词。
  Future<void> setWordListFilter(String? wordList) async {
    filterWordList.value = wordList;
    await loadWords();
  }

  /// 更新指定生词的学习状态。
  Future<void> updateStatus(String id, VocabStatus status) async {
    await vocab_api.updateVocabularyStatus(id: id, status: status);
    await loadWords();
  }

  /// 删除指定生词。
  Future<void> deleteWord(String id) async {
    await vocab_api.deleteVocabulary(id: id);
    await loadWords();
  }

  /// 释放所有 signal 资源。
  void dispose() {
    words.dispose();
    stats.dispose();
    filterStatus.dispose();
    filterWordList.dispose();
    wordLists.dispose();
    bookTitles.dispose();
  }
}
