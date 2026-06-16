import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/async_utils.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/src/rust/api/data/bookmark.dart' as bookmark_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// Standalone bookmark management for a single book.
///
/// Does not depend on an active [ReaderViewModel] session.
class BookmarkManageViewModel {
  BookmarkManageViewModel(this.bookId);

  final String bookId;

  final bookmarks = asyncSignal<List<Bookmark>>(AsyncState.data([]));

  Future<void> loadBookmarks() async {
    await bookmarks.loadAsync(
      () => bookmark_api.listBookmarksByBook(bookId: bookId),
      label: 'loadBookmarks',
    );
  }

  Future<bool> deleteBookmark(String bookmarkId) async {
    try {
      await bookmark_api.deleteBookmark(bookmarkId: bookmarkId);
      await loadBookmarks();
      return true;
    } catch (e) {
      Logging.error('deleteBookmark error', exception: e);
      return false;
    }
  }

  Future<void> batchDelete(List<String> bookmarkIds) async {
    await bookmark_api.deleteBookmarks(bookmarkIds: bookmarkIds);
    await loadBookmarks();
  }

  Future<void> clearAll() async {
    await bookmark_api.clearBookmarksByBook(bookId: bookId);
    await loadBookmarks();
  }
}
