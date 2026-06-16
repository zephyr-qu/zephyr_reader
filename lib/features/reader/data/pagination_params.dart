import 'package:zephyr_reader/features/reader/data/typeset_calibrator.dart';
import 'package:zephyr_reader/src/rust/domain/types/typeset.dart';

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
  final CalibrationData? calibration;
  final String fontFamily;
  final double letterSpacing;
  final double paragraphSpacing;
  final bool punctuationSqueeze;
  final bool firstLineIndent;
  final bool enableHyphenation;
  final LanguageType language;
  final double autoSpaceRatio;

  const PaginationParams({
    required this.fontSize,
    required this.lineHeight,
    required this.width,
    required this.height,
    required this.padding,
    this.devicePixelRatio = 1.0,
    this.calibration,
    this.fontFamily = 'Noto Sans SC',
    this.letterSpacing = 0,
    this.paragraphSpacing = 16,
    this.punctuationSqueeze = true,
    this.firstLineIndent = true,
    this.enableHyphenation = false,
    this.language = LanguageType.auto,
    this.autoSpaceRatio = 0.25,
  });
}
