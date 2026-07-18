/// 行内 ReaderInlineRun → Flutter TextSpan 转换器。
///
/// 分页和 scroll 共用此转换器处理 `ReaderInlineRun[]` → `TextSpan` 树。
/// RichParagraph 管线已移除，scroll 模式走 IR 路径。
library;

import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/reader_engine/shared/ir_types.dart';

class RichTextConverter {
  const RichTextConverter();

  /// 将单个 [ReaderInlineRun] 映射为 [TextStyle]。
  TextStyle spanToStyle(ReaderInlineRun span) {
    final isLink = span.url != null && span.url!.isNotEmpty;
    return TextStyle(
      fontWeight: span.style.bold ? FontWeight.bold : null,
      fontStyle: span.style.italic ? FontStyle.italic : null,
      decoration: isLink ? TextDecoration.underline : null,
      color: isLink ? Colors.blue : null,
    );
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
            (s) =>
                TextSpan(text: s.text, style: blockStyle.merge(spanToStyle(s))),
          )
          .toList(),
    );
  }
}
