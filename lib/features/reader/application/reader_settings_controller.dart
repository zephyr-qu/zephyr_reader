import 'package:signals/signals.dart';

import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'reader_enums.dart';

/// 阅读器设置控制器
///
/// 管理字体、主题、布局等所有持久化阅读设置。
class ReaderSettingsController {
  final ReaderConfig _config;

  ReaderSettingsController(this._config) {
    _loadSettings();
  }

  // ==================== 阅读设置信号 ====================

  final fontSize = signal<double>(18.0);
  final lineHeight = signal<double>(1.5);
  final readerTheme = signal<ReaderTheme>(ReaderTheme.light);
  final letterSpacing = signal<double>(0.0);
  final paragraphSpacing = signal<double>(12.0);
  final pageMargin = signal<double>(16.0);
  final writingDirection = signal<WritingDirection>(
    WritingDirection.horizontal,
  );
  final readerBgColorIndex = signal<int>(0);
  final brightnessOverlay = signal<double>(0.0);

  // ==================== 初始化 ====================

  void _loadSettings() {
    fontSize.value = _config.fontSize.value.size.toDouble();
    lineHeight.value = _config.lineHeight.value;
    readerTheme.value = _config.theme.value;
    paragraphSpacing.value = _config.paragraphSpacing.value;
    pageMargin.value = _config.padding.value;
  }

  // ==================== 操作方法 ====================

  Future<void> setFontSize(double size) async {
    fontSize.value = size;
    await _config.setFontSize(ReaderFontSize.fromSize(size));
  }

  Future<void> setLineHeight(double height) async {
    lineHeight.value = height;
    await _config.setLineHeight(height);
  }

  Future<void> setTheme(ReaderTheme theme) async {
    readerTheme.value = theme;
    await _config.setTheme(theme);
  }

  void setLetterSpacing(double spacing) {
    letterSpacing.value = spacing;
  }

  void setParagraphSpacing(double spacing) {
    paragraphSpacing.value = spacing;
  }

  void setPageMargin(double margin) {
    pageMargin.value = margin;
  }

  void setWritingDirection(WritingDirection direction) {
    writingDirection.value = direction;
  }

  void setReaderBgColor(int index) {
    readerBgColorIndex.value = index;
  }

  void setBrightness(double value) {
    brightnessOverlay.value = value.clamp(0.0, 1.0);
  }

  void dispose() {
    fontSize.dispose();
    lineHeight.dispose();
    readerTheme.dispose();
    letterSpacing.dispose();
    paragraphSpacing.dispose();
    pageMargin.dispose();
    writingDirection.dispose();
    readerBgColorIndex.dispose();
    brightnessOverlay.dispose();
  }
}
