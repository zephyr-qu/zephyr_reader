import 'package:flutter/material.dart' show ValueNotifier;
import 'package:zephyr_reader/features/reader/core/data/next_chapter_staging.dart';
import 'package:zephyr_reader/features/reader/core/data/reader_render_data_source.dart';
import 'package:zephyr_reader/features/reader/core/domain/chapter_content_repository.dart';
import 'package:zephyr_reader/features/reader/flutter_pagination/flutter_pagination_session.dart';
import 'package:zephyr_reader/features/reader/flutter_pagination/packed_page.dart';
import 'package:zephyr_reader/features/reader/data/ir_types.dart';

/// 渲染数据源的默认实现：组合 [ChapterContentRepository] 和 [PaginationSession]。
///
/// 不是业务中间人——只是将两个稳定接口的字段组合给 widget 渲染层消费。
class DefaultReaderRenderDataSource implements ReaderRenderDataSource {
  DefaultReaderRenderDataSource(this._content, this._session);

  final ChapterContentRepository _content;
  final PaginationSession _session;

  @override
  List<PackedPage>? get descriptors => _session.descriptors;

  @override
  String? get sessionFilePath => _session.sessionFilePath;

  @override
  String? pageContent(int pageIndex) => _session.pageContent(pageIndex);

  @override
  List<PackedBlockSlice>? pageBlocks(int pageIndex) =>
      _session.pageBlocks(pageIndex);

  @override
  void warmPageCache(int pageIndex, String content) =>
      _session.warmPageCache(pageIndex, content);

  @override
  ValueNotifier<int> get preloadGeneration => _content.preloadGeneration;

  @override
  ReaderChapterIr? get currentChapterIr => _content.currentChapterIr;

  @override
  String? get currentChapterFilePath => _content.currentChapterFilePath;

  @override
  NextChapterStaging? get nextChapterStaging => _content.nextChapterStaging;

  @override
  NextChapterStaging? get prevChapterStaging => _content.prevChapterStaging;

  @override
  void ensureWindow(int centerPage) => _session.ensureWindow(centerPage);
}
