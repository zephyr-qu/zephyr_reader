/// 基于 Rust 存储的章节仓库实现
library;

import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/local/rust_storage_service.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

@Injectable()
class ChapterRepository {
  final RustStorageService _storage;
  ChapterRepository(this._storage);

  
  Future<List<Chapter>> getChaptersByBookId(int bookId) async {
    return _storage.getChaptersByBook('book_$bookId');
  }

  Future<Chapter?> getChapterByIndex(int bookId, int chapterIndex) async {
    final chapters = await getChaptersByBookId(bookId);
    return chapters.where((c) => c.chapterIndex == chapterIndex).firstOrNull;
  }

  Future<Chapter?> getChapterById(String chapterId) async {
    final chapters = await getChaptersByBookId(
      int.tryParse(chapterId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
    );
    return chapters.where((c) => c.id == chapterId).firstOrNull;
  }

  Future<int> insertChapters(List<Chapter> chapters) async {
    if (chapters.isEmpty) return 0;
    await _storage.saveChapters(chapters.first.bookId, chapters);
    return chapters.length;
  }

  Future<int> deleteChaptersByBookId(int bookId) async {
    await _storage.deleteChaptersByBook('book_$bookId');
    return 0;
  }
}
