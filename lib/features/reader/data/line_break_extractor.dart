/// 行断点索引提取——用 TextPainter 获取 Flutter 引擎 ICU 断行的精确结果。
///
/// # 为什么不用贪心估算？
///
/// Rust 侧 `BlockPaginator` 的贪心断行基于字符宽度表（CJK、Latin
/// 各一个均值），在标点、空格、字号变化等场景下与 Flutter ICU 结果
/// 产生漂移，导致分页估算溢出或不足。
///
/// # 如何获取 Ground Truth？
///
/// Flutter 的 `TextPainter` 不直接暴露每行的字符索引。但通过两步
/// 间接法可以可靠获取：
///
/// 1. `computeLineMetrics()` → 每行的位置（baseline、width、height）
/// 2. 用 `getPositionForOffset(Offset(midX, midY))` 命中某行中点
/// 3. 用 `getLineBoundary(position)` 获取该行精确的字符范围
///
/// 这种方法与 Flutter 渲染引擎共享 ICU 断行结果，是 Ground Truth。
/// 已在 `line_break_alignment_test.dart` C1-C7 中验证。
///
/// # Rust 对接格式
///
/// 返回 `List<int>`——每行结束字符在原文中的偏移量。
/// Rust 侧 `paginate_from_line_breaks` 接收 `Vec<u32>`：
///
/// ```rust
/// lines_per_page = page_height_px / line_height_px
/// // 按 lines_per_page 分组 indices → BlockPageDescriptor
/// ```
library;

import 'package:flutter/material.dart';

/// 使用 TextPainter 从文本中提取行断点索引。
///
/// [text] 渲染全文，[style] 排版样式，[maxWidth] 行宽（逻辑像素）。
///
/// 返回每行结束字符在 [text] 中的偏移量。空文本返回空列表。
/// 索引数量 = 行数。索引总数 <= [text.length]。
List<int> computeLineBreakIndices({
  required String text,
  required TextStyle style,
  required double maxWidth,
}) {
  if (text.isEmpty) return [];

  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxWidth);

  final metrics = tp.computeLineMetrics();
  final indices = <int>[];

  for (final line in metrics) {
    // 取行中心点，精确命中该行
    final centerY = line.baseline - line.ascent + line.ascent / 2;
    final centerX = line.left + line.width / 2;
    final pos = tp.getPositionForOffset(Offset(centerX, centerY));
    final boundary = tp.getLineBoundary(pos);

    // boundary.end 是该行在原文中的结束字符偏移
    indices.add(boundary.end);
  }

  return indices;
}

/// 验证行断点索引的有效性。
///
/// 检查所有索引是否：
/// - 严格递增
/// - 最后一个索引 == [text].length
/// - 在每个断点处，两侧字符不构成应保持的字符对
bool validateLineBreakIndices(List<int> indices, String text) {
  if (indices.isEmpty) return text.isEmpty;

  // 严格递增
  if (indices.length > 1) {
    for (var i = 1; i < indices.length; i++) {
      if (indices[i] <= indices[i - 1]) return false;
    }
  }

  // 最后一个索引 == text.length
  if (indices.last != text.length) return false;

  return true;
}
