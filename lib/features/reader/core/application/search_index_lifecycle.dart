import 'package:async/async.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_view_model.dart';
import 'package:zephyr_reader/src/rust/api/search.dart' as search_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 章节全文搜索索引生命周期管理。
///
/// 在章节内容加载完成后异步索引到 FTS5，切换章节时取消进行中的操作。
class SearchIndexLifecycle {
  final ChapterViewModel _chapterVM;
  final AsyncSignal<List<Chapter>> _chapters;

  CancelableOperation<void>? _searchIndexOperation;

  SearchIndexLifecycle(this._chapterVM, this._chapters);

  /// 取消进行中的索引操作并调度新章节的索引任务。
  Future<void> scheduleIndex(int chapterIndex, String content) async {
    await _searchIndexOperation?.cancel();
    _searchIndexOperation = CancelableOperation.fromFuture(
      _indexForSearch(chapterIndex, content),
      onCancel: () => Logging.debug('_searchIndexOperation cancelled'),
    );
  }

  /// 取消进行中的索引操作（reset 时调用）。
  void cancel() {
    _searchIndexOperation?.cancel();
    _searchIndexOperation = null;
  }

  /// 将章节内容索引到 FTS5（不阻塞 UI，失败静默忽略）。
  Future<void> _indexForSearch(int chapterIndex, String content) async {
    try {
      final chapterList = _chapters.value.value ?? [];
      final title =
          chapterList
              .where((c) => c.chapterIndex == chapterIndex)
              .firstOrNull
              ?.title ??
          '';
      await search_api.indexChapter(
        bookId: _chapterVM.bookId.value,
        chapterId: '${_chapterVM.bookId.value}_$chapterIndex',
        chapterIndex: chapterIndex,
        chapterTitle: title,
        content: content,
      );
    } catch (e) {
      Logging.error('Failed to build full-text search index', exception: e);
    }
  }
}
