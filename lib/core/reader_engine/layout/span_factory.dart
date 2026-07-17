import 'package:flutter/material.dart';

import 'package:zephyr_reader/core/reader_engine/layout/layout_spec.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/reader_render_config.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/rich_text_converter.dart';
import 'package:zephyr_reader/src/rust/pipeline/types.dart';

/// IR → Flutter TextSpan 的统一工厂。
///
/// ADR-018：分页测量与渲染都用同一个 SpanFactory。
/// 替代 IrReaderIrBlock.buildLayoutSpan / RichTextConverter 在 paginator 中的重复调用。
class SpanFactory {
  final LayoutSpec spec;
  final _converter = const RichTextConverter();

  const SpanFactory(this.spec);

  double effectiveFontSize(BlockStyle style) {
    final explicit = style.fontSize;
    if (explicit != null && explicit > 0) return explicit;
    if (style.isHeading && style.headingLevel > 0) {
      return switch (style.headingLevel) {
        1 => spec.fontSize * 1.5,
        2 => spec.fontSize * 1.25,
        3 => spec.fontSize * 1.125,
        4 => spec.fontSize * 1.0,
        _ => spec.fontSize * 0.875,
      };
    }
    return spec.fontSize;
  }

  double effectiveLineHeight() => spec.lineHeight;

  double firstLineIndentPx(BlockStyle style) {
    if (style.isHeading) return 0;
    if (style.textIndentEm != null) {
      final em = style.textIndentEm!;
      return em <= 0 ? 0 : em * spec.fontSize;
    }
    return spec.firstLineIndent ? 2.0 * spec.fontSize : 0;
  }

  EdgeInsets blockPadding(BlockStyle style) {
    final fs = effectiveFontSize(style);
    return EdgeInsets.only(
      top: (style.marginTopEm ?? 0) * fs,
      bottom: (style.marginBottomEm ?? 0) * fs,
    );
  }

  TextStyle blockTextStyle(BlockStyle style) {
    final fs = effectiveFontSize(style);
    return TextStyle(
      fontSize: fs,
      height: spec.lineHeight,
      fontFamily: spec.fontFamily,
      fontFamilyFallback: ReaderRenderConfig.fallbackStack,
      letterSpacing: spec.letterSpacing,
      fontWeight: style.isHeading && style.headingLevel > 0
          ? FontWeight.bold
          : null,
    );
  }

  StrutStyle blockStrutStyle(BlockStyle style) {
    final fs = effectiveFontSize(style);
    return StrutStyle(
      fontFamily: spec.fontFamily,
      fontFamilyFallback: ReaderRenderConfig.fallbackStack,
      fontSize: fs,
      height: spec.lineHeight,
      forceStrutHeight: spec.forceStrutHeight,
      leading: 0,
    );
  }

  TextSpan buildSpan({
    required String text,
    required List<ReaderInlineRun> spans,
    required BlockStyle style,
    bool applyIndent = false,
  }) {
    final baseStyle = blockTextStyle(style);
    if (spans.isEmpty) {
      final span = TextSpan(text: text, style: baseStyle);
      if (!applyIndent) return span;
      return _indentedSpan(span, baseStyle, style);
    }
    final rich = _converter.irSpansToTextSpan(spans, blockStyle: baseStyle);
    if (!applyIndent) return rich;
    return _indentedSpan(rich, baseStyle, style);
  }

  TextSpan _indentedSpan(TextSpan inner, TextStyle base, BlockStyle style) {
    final px = firstLineIndentPx(style);
    if (px <= 0) return inner;
    return TextSpan(
      style: base,
      children: [
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: SizedBox(width: px),
        ),
        inner,
      ],
    );
  }
}
