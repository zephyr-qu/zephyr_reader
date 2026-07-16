import 'package:flutter/material.dart' show ValueNotifier;
import 'package:zephyr_reader/reader_engine/shared/next_chapter_staging.dart';
import 'package:zephyr_reader/reader_engine/data/chapter_content_repository.dart';
import 'package:zephyr_reader/reader_engine/pagination/flutter_pagination_session.dart';
import 'package:zephyr_reader/reader_engine/pagination/packed_page.dart';
import 'package:zephyr_reader/reader_engine/shared/ir_types.dart';

/// 渲染数据源：组合 [ChapterContentRepository] 和 [PaginationSession]。
///
/// 不是业务中间人——只是将两个稳定组件组合给 widget 渲染层消费。
class ReaderRenderDataSource {
  ReaderRenderDataSource(this._content, this._session);

  final ChapterContentRepository _content;
  final PaginationSession _session;

  List<PackedPage>? get descriptors => _session.descriptors;

  String? get sessionFilePath => _session.sessionFilePath;

  String? pageContent(int pageIndex) => _session.pageContent(pageIndex);

  List<PackedBlockSlice>? pageBlocks(int pageIndex) =>
      _session.pageBlocks(pageIndex);

  void warmPageCache(int pageIndex, String content) =>
      _session.warmPageCache(pageIndex, content);

  ValueNotifier<int> get preloadGeneration => _content.preloadGeneration;

  /// scroll IR 块流；非 null 时 [ScrollModeRenderer] 走块渲染。
  ReaderChapterIr? get currentChapterIr => _content.currentChapterIr;

  /// 当前章书籍文件路径（scroll IR 图片）。
  String? get currentChapterFilePath => _content.currentChapterFilePath;

  NextChapterStaging? get nextChapterStaging => _content.nextChapterStaging;

  NextChapterStaging? get prevChapterStaging => _content.prevChapterStaging;

  /// Ensure the window around [centerPage] is cached and trigger widget rebuild.
  void ensureWindow(int centerPage) => _session.ensureWindow(centerPage);
}
