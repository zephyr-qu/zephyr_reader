/// 基于 Rust 存储的章节仓库实现
library;

import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/local/rust_storage_service.dart';
import 'package:zephyr_reader/features/bookshelf/domain/repositories/chapter_repository.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

@Injectable(as: ChapterRepository)
class RustChapterRepository implements ChapterRepository {
  final _storage = RustStorageService();

  @override
  Future<List<DbChapter>> getChaptersByBookId(int bookId) async {
    final rustChapters = _storage.getChaptersByBook('book_$bookId');
    return rustChapters.map(_chapterFromRust).toList();
  }

  @override
  Future<DbChapter?> getChapterByIndex(int bookId, int chapterIndex) async {
    final chapters = await getChaptersByBookId(bookId);
    return chapters.where((c) => c.chapterIndex == chapterIndex).firstOrNull;
  }

  @override
  Future<DbChapter?> getChapterById(String chapterId) async {
    final chapters = await getChaptersByBookId(
      int.tryParse(chapterId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
    );
    return chapters.where((c) => c.id == chapterId).firstOrNull;
  }

  @override
  Future<int> insertChapters(List<DbChapter> chapters) async {
    if (chapters.isEmpty) return 0;
    final bookId = chapters.first.bookId;
    final bookIdStr = 'book_$bookId';
    final rustChapters = chapters
        .map(
          (c) => DbChapter(
            id: 'chapter_${c.id}',
            bookId: bookIdStr,
            title: c.title,
            contentFile: c.contentFile,
            chapterIndex: c.chapterIndex,
            wordCount: c.wordCount,
            cachedAt: c.cachedAt,
            level: c.level,
          ),
        )
        .toList();
    _storage.saveChapters(bookIdStr, rustChapters);
    return chapters.length;
  }

  @override
  Future<int> deleteChaptersByBookId(int bookId) async {
    _storage.deleteChaptersByBook('book_$bookId');
    return 0;
  }

  DbChapter _chapterFromRust(DbChapter rustChapter) {
    return DbChapter(
      id: rustChapter.id,
      bookId: rustChapter.bookId,
      title: rustChapter.title,
      contentFile: rustChapter.contentFile,
      chapterIndex: rustChapter.chapterIndex,
      wordCount: rustChapter.wordCount,
      cachedAt: rustChapter.cachedAt,
      level: rustChapter.level,
    );
  }
}
