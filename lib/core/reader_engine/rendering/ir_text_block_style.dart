import 'package:flutter/material.dart';

import 'package:zephyr_reader/core/reader_engine/rendering/rich_text_converter.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/highlight_painter.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/reader_render_config.dart';
import 'package:zephyr_reader/src/rust/domain/note/models.dart';
import 'package:zephyr_reader/core/reader_engine/shared/ir_types.dart';

/// ADR-010：IR 块样式 → Flutter 排版（scroll + pagination 共用）。
abstract final class IrReaderIrBlock {
  static const double defaultFirstLineIndentEm = 2.0;
  static const _converter = RichTextConverter();

  static double effectiveFontSize(BlockStyle style, ReaderRenderConfig config) {
    final explicit = style.fontSize;
    if (explicit != null && explicit > 0) return explicit;
    if (style.isHeading && style.headingLevel > 0) {
      final multiplier = switch (style.headingLevel) {
        1 => 1.5,
        2 => 1.25,
        3 => 1.125,
        4 => 1.0,
        _ => 0.875,
      };
      return config.fontSize * multiplier;
    }
    return config.fontSize;
  }

  static double effectiveLineHeight(
    BlockStyle style,
    ReaderRenderConfig config,
  ) {
    // ADR-015: EPUB line-height 已丢弃，统一使用用户设置
    return config.lineHeight;
  }

  static TextAlign resolveTextAlign(String? irAlign, TextAlign configDefault) {
    switch (irAlign?.toLowerCase()) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      case 'left':
        return TextAlign.left;
      case 'justify':
        return TextAlign.justify;
      default:
        return configDefault;
    }
  }

  static double resolveFirstLineIndentPx(
    BlockStyle style,
    ReaderRenderConfig config, {
    double defaultIndentEm = defaultFirstLineIndentEm,
  }) {
    if (style.isHeading) return 0;
    // EPUB/CSS 显式 text-indent 优先于用户开关。
    if (style.textIndentEm != null) {
      final em = style.textIndentEm!;
      if (em <= 0) return 0;
      return em * config.fontSize;
    }
    if (!config.firstLineIndent) return 0;
    return defaultIndentEm * config.fontSize;
  }

  static EdgeInsets resolveBlockPadding(
    BlockStyle style,
    ReaderRenderConfig config,
  ) {
    final fs = effectiveFontSize(style, config);
    return EdgeInsets.only(
      top: (style.marginTopEm ?? 0) * fs,
      bottom: (style.marginBottomEm ?? 0) * fs,
    );
  }

  static double resolveBottomSpacing(
    BlockStyle style,
    ReaderRenderConfig config,
  ) {
    if (style.marginBottomEm != null) {
      return style.marginBottomEm! * effectiveFontSize(style, config);
    }
    return config.paragraphSpacing;
  }

  static TextStyle mapToTextStyle(BlockStyle style, ReaderRenderConfig config) {
    var textStyle = config.buildTextStyle();
    textStyle = textStyle.copyWith(height: effectiveLineHeight(style, config));
    if (style.isHeading && style.headingLevel > 0) {
      textStyle = textStyle.copyWith(fontWeight: FontWeight.bold);
    }
    textStyle = textStyle.copyWith(fontSize: effectiveFontSize(style, config));
    return textStyle;
  }

  static TextSpan buildLayoutSpan({
    required String text,
    required List<ReaderInlineRun> spans,
    required BlockStyle irStyle,
    required ReaderRenderConfig config,
  }) {
    final blockStyle = mapToTextStyle(irStyle, config);
    return spans.isEmpty
        ? TextSpan(text: text, style: blockStyle)
        : _converter.irSpansToTextSpan(spans, blockStyle: blockStyle);
  }

  static TextSpan buildHighlightedSpan({
    required String text,
    required List<ReaderInlineRun> spans,
    required BlockStyle irStyle,
    required ReaderRenderConfig config,
    required List<Note> highlights,
    required int contentStart,
    required bool applyFirstLineIndent,
    void Function(Note)? onHighlightTap,
  }) {
    final textStyle = mapToTextStyle(irStyle, config);
    final TextSpan painted;
    if (spans.isNotEmpty) {
      final rich = _converter.irSpansToTextSpan(spans, blockStyle: textStyle);
      painted = HighlightPainter.paintRich(
        rich,
        contentStart,
        highlights,
        onHighlightTap: onHighlightTap,
        vocabularyWords: config.effectiveVocabWords,
      );
    } else {
      painted = HighlightPainter.paintPlain(
        text,
        textStyle,
        highlights,
        onHighlightTap: onHighlightTap,
        vocabularyWords: config.effectiveVocabWords,
        contentStart: contentStart,
      );
    }

    if (!applyFirstLineIndent) return painted;

    final indentPx = resolveFirstLineIndentPx(irStyle, config);
    if (indentPx <= 0) return painted;

    return TextSpan(
      style: textStyle,
      children: [
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: SizedBox(width: indentPx),
        ),
        painted,
      ],
    );
  }
}
