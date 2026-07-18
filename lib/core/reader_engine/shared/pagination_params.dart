import 'package:flutter/painting.dart';
import 'package:zephyr_reader/core/reader_engine/shared/config/reader_typography_defaults.dart';
import 'package:zephyr_reader/core/reader_engine/shared/config/language_type.dart';

/// 分页排版参数聚合体。
///
/// 消除 [ReaderRepository.beginPaginate] 和
/// [ReaderRepository.expandToFullChapter] 中重复的 13 个布局参数。
class PaginationParams {
  final double fontSize;
  final double lineHeight;
  final double width;
  final double height;
  final double padding;
  final double devicePixelRatio;
  final String fontFamily;
  final double letterSpacing;
  final double paragraphSpacing;
  final bool punctuationSqueeze;
  final bool firstLineIndent;
  final LanguageType language;
  final double autoSpaceRatio;
  final bool baselineAlign;
  final TextScaler textScaler;

  const PaginationParams({
    required this.fontSize,
    required this.lineHeight,
    required this.width,
    required this.height,
    required this.padding,
    this.devicePixelRatio = 1.0,
    this.fontFamily = 'Noto Sans SC',
    this.letterSpacing = 0,
    this.paragraphSpacing = ReaderTypographyDefaults.paragraphSpacing,
    this.punctuationSqueeze = true,
    this.firstLineIndent = true,
    this.language = LanguageType.auto,
    this.autoSpaceRatio = 0.25,
    this.baselineAlign = true,
    this.textScaler = TextScaler.noScaling,
  });
}
