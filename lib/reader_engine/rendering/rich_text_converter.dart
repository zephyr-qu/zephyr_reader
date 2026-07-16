/// 行内 ReaderInlineRun → Flutter TextSpan 转换器。
///
/// 分页和 scroll 共用此转换器处理 `ReaderInlineRun[]` → `TextSpan` 树。
/// RichParagraph 管线已随 Phase 8 移除，scroll 模式走 IR 路径。
library;

import 'package:flutter/material.dart';
import 'package:zephyr_reader/reader_engine/shared/ir_types.dart';

class RichTextConverter {
  const RichTextConverter();

  /// 将单个 [ReaderInlineRun] 映射为 [TextStyle]。
  TextStyle spanToStyle(ReaderInlineRun span) {
    if (span.url != null && span.url!.isNotEmpty) {
      return const TextStyle(
        decoration: TextDecoration.underline,
        color: Colors.blue,
      );
    }
    return switch (span.style) {
      ReaderInlineStyle.plain => const TextStyle(),
      ReaderInlineStyle.bold => const TextStyle(fontWeight: FontWeight.bold),
      ReaderInlineStyle.italic => const TextStyle(fontStyle: FontStyle.italic),
    };
  }

  /// 将 IR 行内 [ReaderInlineRun] 列表转为 [TextSpan] 树（块级样式作基底）。
  TextSpan irSpansToTextSpan(
    List<ReaderInlineRun> spans, {
    required TextStyle blockStyle,
  }) {
    if (spans.isEmpty) {
      return TextSpan(text: '', style: blockStyle);
    }
    return TextSpan(
      style: blockStyle,
      children: spans
          .map(
            (s) => TextSpan(
              text: s.text,
              style: blockStyle.merge(spanToStyle(s)),
            ),
          )
          .toList(),
    );
  }
}
