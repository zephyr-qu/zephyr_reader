import 'package:zephyr_reader/reader_engine/rendering/reader_render_config.dart';

/// 滚动 ListView 项高度估算所需的排版参数。
class ScrollLayoutParams {
  const ScrollLayoutParams({
    required this.textRowHeight,
    required this.paragraphSpacing,
    required this.contentWidth,
    required this.fontSize,
  });

  final double textRowHeight;
  final double paragraphSpacing;
  final double contentWidth;
  final double fontSize;

  factory ScrollLayoutParams.fromRenderConfig(
    ReaderRenderConfig config, {
    required double viewportWidth,
  }) {
    final contentWidth = (viewportWidth - 2 * config.pageMargin).clamp(
      1.0,
      viewportWidth,
    );
    return ScrollLayoutParams(
      textRowHeight: config.textRowHeight,
      paragraphSpacing: config.paragraphSpacing,
      contentWidth: contentWidth,
      fontSize: config.fontSize,
    );
  }

  /// 单行文本项 fallback 高度（含段间距）。
  double get uniformTextExtent => textRowHeight + paragraphSpacing;
}
