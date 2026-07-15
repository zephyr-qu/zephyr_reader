/// 行内 RichTextSpan → Flutter TextSpan 转换器。
///
/// 分页和 scroll 共用此转换器处理 `RichTextSpan[]` → `TextSpan` 树。
/// RichParagraph 管线已随 Phase 8 移除，scroll 模式走 IR 路径。
library;

import 'package:flutter/material.dart';
import 'package:zephyr_reader/src/rust/pipeline/types.dart';

/// 从 [RichTextSpan] 提取纯文本。
String _spanText(RichTextSpan span) =>
    span.when(styled: (_, data) => data.text, link: (data, _) => data.text);

class RichTextConverter {
  const RichTextConverter();

  /// 将单个 [RichTextSpan] 映射为 [TextStyle]。
  TextStyle spanToStyle(RichTextSpan span) {
    return span.when(
      styled: (style, data) => switch (style) {
        SpanStyle.plain => const TextStyle(),
        SpanStyle.bold => const TextStyle(fontWeight: FontWeight.bold),
        SpanStyle.italic => const TextStyle(fontStyle: FontStyle.italic),
      },
      link: (data, url) => const TextStyle(
        decoration: TextDecoration.underline,
        color: Colors.blue,
      ),
    );
  }

  /// 将 IR 行内 [RichTextSpan] 列表转为 [TextSpan] 树（块级样式作基底）。
  TextSpan irSpansToTextSpan(
    List<RichTextSpan> spans, {
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
              text: _spanText(s),
              style: blockStyle.merge(spanToStyle(s)),
            ),
          )
          .toList(),
    );
  }
}
