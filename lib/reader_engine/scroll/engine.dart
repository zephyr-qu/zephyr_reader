import 'package:flutter/material.dart';
import 'package:zephyr_reader/reader_engine/rendering/reader_render_config.dart';
import 'package:zephyr_reader/reader_engine/shared/ir_types.dart';

/// 滚动引擎：无状态工厂，提供滚动模式排版工具。
///
/// 与 [PaginationEngine] 不同，ScrollEngine 不持有运行时状态，
/// 滚动视图随 widget 树重建，无需显式释放。
class ScrollEngine {
  /// IR 内容是否为图文混合（含图片块）。
  static bool hasImages(ReaderChapterIr ir) =>
      ir.blocks.any((b) => b.kind == ReaderIrBlockKind.image);

  /// 根据 IR 构建滚动块列表。
  static List<Widget> buildBlocks({
    required ReaderChapterIr ir,
    required ReaderRenderConfig config,
    required String epubFilePath,
  }) {
    final blocks = <Widget>[];
    for (final block in ir.blocks) {
      if (block.kind == ReaderIrBlockKind.image) {
        // TODO: 图片 widget 构建
        continue;
      }
      // 文本块由 ScrollIrBlockList 渲染
    }
    return blocks;
  }
}
