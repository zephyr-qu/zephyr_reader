import 'package:flutter/material.dart';
import 'package:zephyr_reader/features/reader/data/pagination_engine.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';
import 'package:zephyr_reader/src/rust/domain/types/rich_text.dart';

/// 渲染器所需的数据源：分页会话状态 + 富文本 + 预加载。
abstract class ReaderRenderDataSource {
  List<PageDescriptor>? get descriptors;

  List<PageInfo>? get approximatePages;

  String? pageContent(int pageIndex);

  void warmPageCache(int pageIndex, String content);

  ValueNotifier<int> get preloadGeneration;

  String? getPreloadedNextChapterContent(
    int chapterIndex, {
    int pageIndex = 0,
  });

  TextSpan? get currentRichContent;

  List<RichParagraph>? get currentRichParagraphs;
}
