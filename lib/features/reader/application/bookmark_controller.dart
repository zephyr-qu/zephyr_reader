import 'package:signals/signals.dart';
import 'package:zephyr_reader/core/utils/logging.dart';

import '../data/repositories/rust_reader_repository.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 书签控制器
///
/// 管理书签列表的增删查，不依赖其他 Controller。
class BookmarkController {
  final ReaderRepository _repo;

  BookmarkController(this._repo);

  /// 书签列表
  final bookmarks = asyncSignal<List<Bookmark>>(AsyncState.data([]));

  /// 加载书签
  Future<void> loadBookmarks(String bookId) async {
    bookmarks.value = AsyncState.loading();
    try {
      final data = await _repo.getBookmarks(bookId);
      bookmarks.value = AsyncState.data(data);
    } catch (e) {
      bookmarks.value = AsyncState.error(e);
    }
  }

  /// 添加书签
  Future<bool> addBookmark(
    String bookId,
    int chapterIndex,
    int charOffset,
  ) async {
    try {
      await _repo.addBookmark(bookId, chapterIndex, charOffset);
      await loadBookmarks(bookId);
      return true;
    } catch (e) {
      Logging.error('BookmarkController.addBookmark error', exception: e);
      return false;
    }
  }

  /// 删除书签
  Future<bool> deleteBookmark(String bookmarkId, String bookId) async {
    try {
      final success = await _repo.deleteBookmark(bookmarkId);
      if (success) {
        await loadBookmarks(bookId);
      }
      return success;
    } catch (e) {
      Logging.error('BookmarkController.deleteBookmark error', exception: e);
      return false;
    }
  }

  void dispose() {
    bookmarks.dispose();
  }
}
