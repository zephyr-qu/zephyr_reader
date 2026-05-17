library;

import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/src/rust/api/vocabulary.dart' as vocab_api;

@injectable
class VocabularyService {
  Future<vocab_api.VocabEntry> addWord({
    required String word,
    String pinyin = '',
    required String translation,
    String? contextSentence,
    String? bookId,
    int? chapterIndex,
    int? charOffset,
  }) async {
    return vocab_api.addVocabularyWord(
      word: word,
      pinyin: pinyin,
      translation: translation,
      contextSentence: contextSentence,
      bookId: bookId,
      chapterIndex: chapterIndex,
      charOffset: charOffset,
    );
  }

  Future<List<vocab_api.VocabEntry>> getWords({
    String? bookId,
    String? status,
  }) async {
    return vocab_api.getVocabularyWords(bookId: bookId, status: status);
  }

  Future<List<vocab_api.VocabEntry>> search(String query) async {
    return vocab_api.searchVocabulary(query: query);
  }

  Future<void> updateStatus(String id, String status) async {
    await vocab_api.updateVocabularyStatus(id: id, status: status);
  }

  Future<void> delete(String id) async {
    await vocab_api.deleteVocabularyWord(id: id);
  }

  Future<vocab_api.VocabStats> getStats() async {
    return vocab_api.getVocabularyStats();
  }
}
