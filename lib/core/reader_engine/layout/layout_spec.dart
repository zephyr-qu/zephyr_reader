import 'package:flutter/material.dart';

import 'package:zephyr_reader/core/reader_engine/shared/config/language_type.dart';
import 'package:zephyr_reader/core/reader_engine/rendering/reader_render_config.dart';
import 'package:zephyr_reader/core/reader_engine/shared/pagination_params.dart';

/// 不可变排版参数聚合体 - 影响断行和分页的全部参数。
///
/// ADR-018：渲染组件不得从 MediaQuery/Theme 隐式读取影响布局的参数。
/// 颜色、背景色、高亮和选择状态不影响布局，不应进入此类型。
@immutable
class LayoutSpec {
  // ── 视口 ──
  final double viewportWidth;
  final double viewportHeight;
  final double contentPadding;

  // ── 排版 ──
  final String fontFamily;
  final double fontSize;
  final double lineHeight;
  final double letterSpacing;
  final double paragraphSpacing;
  final TextScaler textScaler;
  final bool baselineAlign;
  final bool forceStrutHeight;

  // ── 段落 ──
  final TextAlign textAlign;
  final TextDirection textDirection;
  final TextHeightBehavior textHeightBehavior;
  final bool firstLineIndent;
  final bool punctuationSqueeze;

  // ── 语言 ──
  final LanguageType language;
  final double autoSpaceRatio;

  const LayoutSpec({
    required this.viewportWidth,
    required this.viewportHeight,
    required this.contentPadding,
    required this.fontFamily,
    required this.fontSize,
    required this.lineHeight,
    this.letterSpacing = 0,
    required this.paragraphSpacing,
    this.textScaler = TextScaler.noScaling,
    this.baselineAlign = true,
    this.forceStrutHeight = true,
    this.textAlign = TextAlign.justify,
    this.textDirection = TextDirection.ltr,
    this.textHeightBehavior = ReaderRenderConfig.textHeightBehavior,
    this.firstLineIndent = true,
    this.punctuationSqueeze = true,
    this.language = LanguageType.auto,
    this.autoSpaceRatio = 0.25,
  });

  /// 从 ReaderRenderConfig 构造（渲染端）。
  factory LayoutSpec.fromRenderConfig(
    ReaderRenderConfig config, {
    required double viewportWidth,
    required double viewportHeight,
  }) {
    return LayoutSpec(
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
      contentPadding: config.pageMargin,
      fontFamily: config.fontFamily,
      fontSize: config.fontSize,
      lineHeight: config.lineHeight,
      letterSpacing: config.letterSpacing,
      paragraphSpacing: config.paragraphSpacing,
      textScaler: config.textScaler,
      baselineAlign: config.baselineAlign,
      forceStrutHeight: config.baselineAlign,
      textAlign: config.textAlign,
      firstLineIndent: config.firstLineIndent,
    );
  }

  /// 从 PaginationParams 构造（分页端）。
  factory LayoutSpec.fromPaginationParams(PaginationParams params) {
    return LayoutSpec(
      viewportWidth: params.width,
      viewportHeight: params.height,
      contentPadding: params.padding,
      fontFamily: params.fontFamily,
      fontSize: params.fontSize,
      lineHeight: params.lineHeight,
      letterSpacing: params.letterSpacing,
      paragraphSpacing: params.paragraphSpacing,
      textScaler: params.textScaler,
      baselineAlign: params.baselineAlign,
      forceStrutHeight: params.baselineAlign,
      firstLineIndent: params.firstLineIndent,
      punctuationSqueeze: params.punctuationSqueeze,
      language: params.language,
      autoSpaceRatio: params.autoSpaceRatio,
    );
  }

  double get contentWidth => (viewportWidth - 2 * contentPadding).clamp(1.0, 4096.0);
  double get contentHeight => (viewportHeight - 2 * ReaderRenderConfig.pageContentVerticalPadding).clamp(1.0, 8192.0);
}
