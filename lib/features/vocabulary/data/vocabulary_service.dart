library;

import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/local/rust_storage_service.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

@injectable
class VocabularyService {
  final RustStorageService _storage;

  VocabularyService(this._storage);

  Future<VocabEntry> addWord({
    required String word,
    String pinyin = '',
    required String translation,
    String? contextSentence,
    String? bookId,
    int? chapterIndex,
    int? charOffset,
  }) async {
    return _storage.addVocabularyWord(
      word: word,
      pinyin: pinyin,
      translation: translation,
      contextSentence: contextSentence,
      bookId: bookId,
      chapterIndex: chapterIndex,
      charOffset: charOffset,
    );
  }

  Future<List<VocabEntry>> getWords({String? bookId, String? status}) async {
    return _storage.getVocabularyWords(bookId: bookId, status: status);
  }

  Future<List<VocabEntry>> search(String query) async {
    return _storage.searchVocabulary(query);
  }

  Future<void> updateStatus(String id, String status) async {
    await _storage.updateVocabularyStatus(id: id, status: status);
  }

  Future<void> delete(String id) async {
    await _storage.deleteVocabularyWord(id: id);
  }

  Future<VocabStats> getStats() async {
    return _storage.getVocabularyStats();
  }
}
