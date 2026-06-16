import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/async_utils.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/src/rust/api/data/bookmark.dart' as bookmark_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/features/reader/core/application/reader_page_state.dart';

/// 书签视图模型。
///
/// 管理当前书籍的书签信号和 CRUD 操作、位置索引和跨章节跳转。
class BookmarkViewModel {
  final ReaderPageState _pageState;

  final bookmarks = asyncSignal<List<Bookmark>>(AsyncState.data([]));

  /// 书签位置索引（"chapterIndex:charOffset" → Bookmark），O(1) 查找。
  late final ReadonlySignal<Map<String, Bookmark>> bookmarkIndex = computed(() {
    final list = bookmarks.value.value ?? [];
    final map = <String, Bookmark>{};
    for (final b in list) {
      map['${b.chapterIndex}:${b.charOffset}'] = b;
    }
    return map;
  });

  BookmarkViewModel(this._pageState);

  /// 加载当前书籍的所有书签。
  Future<void> loadBookmarks() async {
    await bookmarks.loadAsync(
      () => bookmark_api.listBookmarksByBook(bookId: _pageState.bookId.value),
      label: 'loadBookmarks',
    );
  }

  /// 在当前阅读位置添加书签。
  ///
  /// [chapterTitle] 作为书签标题，默认使用章节名。
  Future<bool> addBookmark({String chapterTitle = '书签'}) async {
    try {
      await bookmark_api.createBookmark(
        bookId: _pageState.bookId.value,
        chapterIndex: _pageState.chapterIndex.value,
        charOffset: _pageState.currentCharOffset.value,
        title: chapterTitle,
      );
      await loadBookmarks();
      return true;
    } catch (e) {
      Logging.error('addBookmark error', exception: e);
      return false;
    }
  }

  /// 删除指定书签。
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

  /// 当前阅读位置是否存在书签。
  bool get hasBookmarkAtCurrentPosition {
    final key =
        '${_pageState.chapterIndex.value}:${_pageState.currentCharOffset.value}';
    return bookmarkIndex.value.containsKey(key);
  }

  /// 获取当前阅读位置的书签（如果存在）。
  Bookmark? get currentBookmark {
    final key =
        '${_pageState.chapterIndex.value}:${_pageState.currentCharOffset.value}';
    return bookmarkIndex.value[key];
  }

  /// 切换当前阅读位置的书签状态（添加/删除）。
  Future<bool> toggleAtCurrentPosition() async {
    final existing = currentBookmark;
    if (existing != null) {
      return await deleteBookmark(existing.id);
    } else {
      return await addBookmark();
    }
  }

  /// 重置所有信号到初始状态。
  void reset() {
    bookmarks.value = AsyncState.data([]);
  }
}
