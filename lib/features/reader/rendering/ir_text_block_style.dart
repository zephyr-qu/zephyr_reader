import 'package:flutter/material.dart';

import 'package:zephyr_reader/features/reader/rendering/highlight_painter.dart';
import 'package:zephyr_reader/features/reader/rendering/reader_render_config.dart';
import 'package:zephyr_reader/src/rust/domain/types/content_ir.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// ADR-010：IR 块样式 → Flutter 排版（scroll + pagination 共用）。
abstract final class IrTextBlockStyle {
  static const double defaultFirstLineIndentEm = 2.0;

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
    TextBlockStyle style,
    ReaderRenderConfig config, {
    double defaultIndentEm = defaultFirstLineIndentEm,
  }) {
    if (style.isHeading) return 0;
    final em = style.textIndentEm ?? defaultIndentEm;
    if (em <= 0) return 0;
    return em * config.fontSize;
  }

  static EdgeInsets resolveBlockPadding(
    TextBlockStyle style,
    ReaderRenderConfig config,
  ) {
    final fs = config.fontSize;
    return EdgeInsets.only(
      top: (style.marginTopEm ?? 0) * fs,
      bottom: (style.marginBottomEm ?? 0) * fs,
    );
  }

  static double resolveBottomSpacing(
    TextBlockStyle style,
    ReaderRenderConfig config,
  ) {
    if (style.marginBottomEm != null) {
      return style.marginBottomEm! * config.fontSize;
    }
    return config.paragraphSpacing;
  }

  static TextStyle mapToTextStyle(
    TextBlockStyle style,
    ReaderRenderConfig config,
  ) {
    var textStyle = config.buildTextStyle(
      fontFamily:
          style.fontFamily != null && style.fontFamily!.isNotEmpty
              ? style.fontFamily
              : null,
    );
    if (style.lineHeight != null && style.lineHeight! > 0) {
      textStyle = textStyle.copyWith(height: style.lineHeight);
    }
    if (style.isHeading && style.headingLevel > 0) {
      final headingFs = switch (style.headingLevel) {
        1 => 24.0,
        2 => 20.0,
        3 => 18.0,
        4 => 16.0,
        _ => 14.0,
      };
      if (textStyle.fontSize == config.fontSize) {
        textStyle = textStyle.copyWith(fontSize: headingFs);
      }
      textStyle = textStyle.copyWith(fontWeight: FontWeight.bold);
    }
    return textStyle;
  }

  static TextSpan buildHighlightedSpan({
    required String text,
    required TextBlockStyle irStyle,
    required ReaderRenderConfig config,
    required List<Note> highlights,
    required int contentStart,
    required bool applyFirstLineIndent,
    void Function(Note)? onHighlightTap,
  }) {
    final textStyle = mapToTextStyle(irStyle, config);
    final painted = HighlightPainter.paintPlain(
      text,
      textStyle,
      highlights,
      onHighlightTap: onHighlightTap,
      vocabularyWords: config.effectiveVocabWords,
      contentStart: contentStart,
    );

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
