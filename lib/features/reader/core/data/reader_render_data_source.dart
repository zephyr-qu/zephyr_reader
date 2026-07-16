import 'package:flutter/material.dart' show ValueNotifier;
import 'package:zephyr_reader/features/reader/flutter_pagination/packed_page.dart';
import 'package:zephyr_reader/features/reader/core/data/next_chapter_staging.dart';
import 'package:zephyr_reader/features/reader/data/ir_types.dart';

/// 渲染器所需的数据源：分页会话状态 + 富文本 + 预加载。
abstract class ReaderRenderDataSource {
  List<PackedPage>? get descriptors;

  String? get sessionFilePath;

  String? pageContent(int pageIndex);

  List<PackedBlockSlice>? pageBlocks(int pageIndex);

  void warmPageCache(int pageIndex, String content);

  ValueNotifier<int> get preloadGeneration;

  /// scroll IR 块流；非 null 时 [ScrollModeRenderer] 走块渲染。
  ReaderChapterIr? get currentChapterIr;

  /// 当前章书籍文件路径（scroll IR 图片）。
  String? get currentChapterFilePath;

  NextChapterStaging? get nextChapterStaging;

  NextChapterStaging? get prevChapterStaging;

  /// Ensure the window around [centerPage] is cached and trigger widget rebuild.
  void ensureWindow(int centerPage);
}
