/// 富文本 → Flutter Widget 渲染树转换器
///
/// 将 Rust 侧解析的 [RichParagraph]/[RichTextSpan]（EPUB/MD 排版结果）
/// 转换为 Flutter [TextSpan] 树，同时提取纯文本内容。
/// 纯函数，无状态，无 FRB 依赖，可单独做纯 Dart 单元测试。
library;

import 'package:flutter/material.dart';
import 'package:zephyr_reader/src/rust/domain/types/rich_text.dart';

/// 富文本转换器
///
/// 用法：
/// ```dart
/// final converter = RichTextConverter();
/// final (span, plain) = converter.toTextSpan(paragraphs);
/// ```

/// 从 [RichTextSpan] 提取纯文本内容的辅助函数。
String _spanText(RichTextSpan span) =>
    span.when(styled: (_, data) => data.text, link: (data, _) => data.text);

class RichTextConverter {
  const RichTextConverter();

  /// 将 [RichParagraph] 列表转换为 [TextSpan] 树（保留样式），
  /// 同时返回拼接后的纯文本。
  ///
  /// 跳过图片段落（`p.isImage == true`）。
  /// 段落之间插入 `\n\n` 分隔。
  (TextSpan, String) toTextSpan(
    List<RichParagraph> paragraphs, {
    double baseFontSize = 16,
    double baseLineHeight = 1.6,
  }) {
    final children = <InlineSpan>[];
    final plainParts = <String>[];
    for (int i = 0; i < paragraphs.length; i++) {
      final p = paragraphs[i];
      if (p.isImage) continue;

      final paraText = p.spans.map(_spanText).join();
      if (paraText.isEmpty) continue;

      final blockStyle = paragraphBlockStyle(
        p,
        baseFontSize: baseFontSize,
        baseLineHeight: baseLineHeight,
      );
      final spanChildren = p.spans
          .map((s) => TextSpan(text: _spanText(s), style: spanToStyle(s)))
          .toList();

      if (blockStyle != const TextStyle()) {
        children.add(TextSpan(style: blockStyle, children: spanChildren));
      } else {
        children.addAll(spanChildren);
      }
      plainParts.add(paraText);

      if (i < paragraphs.length - 1) {
        children.add(const TextSpan(text: '\n\n'));
      }
    }
    final plain = plainParts.where((t) => t.isNotEmpty).join('\n\n');
    return (TextSpan(children: children), plain);
  }

  /// 将单个 [RichTextSpan] 映射为 [TextStyle]。
  TextStyle spanToStyle(RichTextSpan span) {
    return span.when(
      styled: (style, data) {
        final base = switch (style) {
          SpanStyle.plain => const TextStyle(),
          SpanStyle.bold => const TextStyle(fontWeight: FontWeight.bold),
          SpanStyle.italic => const TextStyle(fontStyle: FontStyle.italic),
          SpanStyle.boldItalic => const TextStyle(
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
          SpanStyle.underline => const TextStyle(
            decoration: TextDecoration.underline,
          ),
          SpanStyle.strikethrough => const TextStyle(
            decoration: TextDecoration.lineThrough,
          ),
          SpanStyle.code => const TextStyle(fontFamily: 'monospace'),
        };
        if (data.fontSize == null && data.color == null) return base;
        return base.copyWith(
          fontSize: data.fontSize,
          color: data.color != null ? parseCssColor(data.color!) : null,
        );
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

  /// 生成段落级样式（CSS block 属性 + 标题回退）。
  TextStyle paragraphBlockStyle(
    RichParagraph p, {
    required double baseFontSize,
    required double baseLineHeight,
  }) {
    TextStyle style = TextStyle(fontSize: baseFontSize, height: baseLineHeight);
    if (p.lineHeight != null) {
      style = style.copyWith(height: p.lineHeight);
    }
    if (p.isHeading && p.headingLevel > 0) {
      final headingFs = switch (p.headingLevel) {
        1 => 24.0,
        2 => 20.0,
        3 => 18.0,
        4 => 16.0,
        _ => 14.0,
      };
      if (style.fontSize == null || style.fontSize == baseFontSize) {
        style = style.copyWith(fontSize: headingFs);
      }
      style = style.copyWith(fontWeight: FontWeight.bold);
    }
    return style;
  }

  /// 解析 CSS 十六进制颜色字符串。
  ///
  /// 支持格式：
  /// - `#RRGGBB`（6 位）
  /// - `#RGB`（3 位，每位重复）
  ///
  /// 解析失败返回 `null`（不抛出异常）。
  Color? parseCssColor(String hex) {
    try {
      final h = hex.replaceFirst('#', '');
      if (h.length == 6) {
        final r = int.parse(h.substring(0, 2), radix: 16);
        final g = int.parse(h.substring(2, 4), radix: 16);
        final b = int.parse(h.substring(4, 6), radix: 16);
        return Color.fromARGB(255, r, g, b);
      }
      if (h.length == 3) {
        final r = int.parse(h[0] * 2, radix: 16);
        final g = int.parse(h[1] * 2, radix: 16);
        final b = int.parse(h[2] * 2, radix: 16);
        return Color.fromARGB(255, r, g, b);
      }
    } catch (_) {
      // hex 格式无效，返回 null
    }
    return null;
  }
}
