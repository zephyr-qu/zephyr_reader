import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/database/database.dart';
import 'package:zephyr_reader/domain/models/chapter.dart';

import '../../domain/repositories/chapter_repository.dart';

/// 章节数据仓库实现
@LazySingleton(as: ChapterRepository)
class ChapterRepositoryImpl implements ChapterRepository {
  final AppDatabase _database;

  ChapterRepositoryImpl(this._database);

  @override
  Future<List<Chapter>> getChaptersByBookId(int bookId) async {
    final chapters = await _database.getChaptersByBookId(bookId);
    return chapters.map((c) => Chapter.fromDb(c)).toList();
  }

  @override
  Future<Chapter?> getChapterByIndex(int bookId, int chapterIndex) async {
    final chapter = await _database.getChapter(bookId, chapterIndex);
    return chapter != null ? Chapter.fromDb(chapter) : null;
  }

  @override
  Future<Chapter?> getChapterById(int chapterId) async {
    final chapter = await _database.getChapterById(chapterId);
    return chapter != null ? Chapter.fromDb(chapter) : null;
  }

  @override
  Future<int> insertChapters(List<DbChaptersCompanion> chapters) async {
    int insertedCount = 0;
    await _database.transaction(() async {
      for (final chapter in chapters) {
        await _database.into(_database.dbChapters).insert(chapter);
        insertedCount++;
      }
    });
    return insertedCount;
  }

  @override
  Future<int> deleteChaptersByBookId(int bookId) async {
    return await (_database.delete(_database.dbChapters)
          ..where((tbl) => tbl.bookId.equals(bookId)))
        .go();
  }
}
