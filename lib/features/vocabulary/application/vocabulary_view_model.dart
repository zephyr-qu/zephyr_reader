import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/src/rust/api/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/api/vocab.dart' as vocab_api;
import 'package:zephyr_reader/src/rust/domain/vocabulary/models.dart';


/// 生词本 ViewModel。
///
/// 管理生词列表、学习统计和筛选状态的异步加载。
class VocabularyViewModel {
  final words = asyncSignal<List<Vocab>>(AsyncState.data([]));
  final stats = asyncSignal<VocabStats?>(AsyncState.loading());
  final wordLists = asyncSignal<List<String>>(AsyncState.loading());
  final bookTitles = asyncSignal<Map<String, String>>(AsyncState.loading());

  /// 加载生词列表、生词统计和书籍标题。
  ///
  /// [status] 和 [wordList] 筛选参数由页面传入，不再存储为 VM 信号。
  Future<void> loadWords({VocabStatus? status, String? wordList}) async {
    try {
      final results = await Future.wait([
        vocab_api.listVocabularyByStatus(status: status, wordList: wordList),
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

  /// 刷新生词列表（保留当前筛选）。
  Future<void> refresh({VocabStatus? status, String? wordList}) async {
    await loadWords(status: status, wordList: wordList);
  }

  /// 更新指定生词的学习状态。
  Future<void> updateStatus(
    String id,
    VocabStatus status, {
    VocabStatus? currentFilter,
    String? currentWordList,
  }) async {
    await vocab_api.updateVocabularyStatus(id: id, status: status);
    await loadWords(status: currentFilter, wordList: currentWordList);
  }

  /// 删除指定生词。
  Future<void> deleteWord(
    String id, {
    VocabStatus? currentFilter,
    String? currentWordList,
  }) async {
    await vocab_api.deleteVocabulary(id: id);
    await loadWords(status: currentFilter, wordList: currentWordList);
  }

  /// 释放所有 signal 资源。
  void dispose() {
    words.dispose();
    stats.dispose();
    wordLists.dispose();
    bookTitles.dispose();
  }
}
