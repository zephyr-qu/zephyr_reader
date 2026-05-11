/// 基于 Rust 存储的阅读器仓库实现
library;

import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/local/rust_storage_service.dart';
import 'package:zephyr_reader/features/reader/domain/repositories/reader_repository.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

@Injectable(as: ReaderRepository)
class RustReaderRepository implements ReaderRepository {
  final RustStorageService _storage;
  RustReaderRepository(this._storage);

  @override
  Future<Chapter?> getChapter(int bookId, int chapterIndex) async {
    final chapters = await _storage.getChaptersByBook('book_$bookId');
    try {
      return chapters.firstWhere((c) => c.chapterIndex == chapterIndex);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Chapter>> getChapters(int bookId) async {
    return _storage.getChaptersByBook('book_$bookId');
  }

  @override
  Future<void> saveReadingHistory(
    String bookId,
    int chapterId,
    int position,
    int duration,
  ) async {
    final now = DateTime.now();
    await _storage.recordReadingSession(ReadingSession(
      id: 'session_${now.millisecondsSinceEpoch}',
      bookId: 'book_$bookId',
      chapterIndex: chapterId,
      startCharOffset: 0,
      endCharOffset: position,
      startedAt: now,
      endedAt: now,
      durationSeconds: duration,
    ));
  }

  @override
  Future<GlobalStats?> getReadingHistory(int bookId) async {
    return _storage.getGlobalReadingStats();
  }

  @override
  Future<int> addBookmark(
    String bookId,
    int chapterId,
    int position,
  ) async {
    final bookmark = Bookmark(
      id: 'bm_${DateTime.now().millisecondsSinceEpoch}',
      bookId: 'book_$bookId',
      chapterIndex: chapterId,
      charOffset: position,
      title: '书签',
      createdAt: DateTime.now(),
    );
    await _storage.createBookmark(bookmark);
    return bookmark.id.hashCode;
  }

  @override
  Future<List<Bookmark>> getBookmarks(String bookId) async {
    return _storage.getBookmarks('book_$bookId');
  }

  @override
  Future<bool> deleteBookmark(int bookmarkId) async {
    try {
      await _storage.deleteBookmark('bm_$bookmarkId');
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> getChapterContent(String contentFile) async {
    final file = File(contentFile);
    if (!await file.exists()) return null;
    return file.readAsString();
  }
}
