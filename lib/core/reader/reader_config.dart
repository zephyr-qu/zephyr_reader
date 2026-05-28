import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 阅读器主题
enum ReaderTheme {
  light('light', '日间', Colors.white, Color(0xFF1A1C1E)),
  dark('dark', '夜间', Color(0xFF0A0F10), Color(0xFFE4E7E7)),
  sepia('sepia', '护眼', Color(0xFFF8F4EA), Color(0xFF4A3F35));

  final String id;
  final String displayName;
  final Color backgroundColor;
  final Color textColor;

  const ReaderTheme(
    this.id,
    this.displayName,
    this.backgroundColor,
    this.textColor,
  );

  static ReaderTheme fromId(String id) {
    return ReaderTheme.values.firstWhere(
      (theme) => theme.id == id,
      orElse: () => ReaderTheme.light,
    );
  }
}

/// 阅读器字体大小
enum ReaderFontSize {
  small(14, '小'),
  medium(16, '中'),
  large(18, '大'),
  xLarge(20, '特大');

  final double size;
  final String displayName;

  const ReaderFontSize(this.size, this.displayName);

  static ReaderFontSize fromSize(double size) {
    return ReaderFontSize.values.firstWhere(
      (fontSize) => fontSize.size == size,
      orElse: () => ReaderFontSize.medium,
    );
  }
}

/// 阅读器配置
@Singleton()
class ReaderBgColors {
  static const darkBackground = Color(0xFF0A0A0A);
  static const presets = [
    Color(0xFFFAFAFA), // 默认白
    Color(0xFFF5F0E8), // 羊皮纸
    Color(0xFFFFF8E7), // 奶油
    Color(0xFFC7EDCC), // 护眼绿
    Color(0xFFF0F0F0), // 灰色
  ];
}

@Singleton()
class ReaderConfig {
  final SharedPreferences prefs;

  /// 当前主题
  final theme = signal<ReaderTheme>(ReaderTheme.light);

  /// 字体大小
  final fontSize = signal<ReaderFontSize>(ReaderFontSize.medium);

  /// 行间距
  final lineHeight = signal<double>(1.6);

  /// 段落间距
  final paragraphSpacing = signal<double>(16.0);

  /// 页边距
  final padding = signal<double>(16.0);

  /// 阅读背景色预设索引
  final readerBgColorIndex = signal<int>(0);

  /// 是否自动翻页
  final autoScroll = signal<bool>(false);

  /// 自动翻页速度（秒）
  final autoScrollSpeed = signal<int>(30);

  /// 字间距
  final letterSpacing = signal<double>(0.0);

  /// 标点挤压
  final punctuationSqueeze = signal<bool>(true);

  /// 中西文基线对齐
  final baselineAlign = signal<bool>(true);

  ReaderConfig(this.prefs) {
    _loadSettings();
  }

  static const String _keyTheme = 'reader_theme';
  static const String _keyFontSize = 'reader_font_size';
  static const String _keyLineHeight = 'reader_line_height';
  static const String _keyParagraphSpacing = 'reader_paragraph_spacing';
  static const String _keyPadding = 'reader_padding';
  static const String _keyReaderBgColorIndex = 'reader_bg_color_index';
  static const String _keyAutoScroll = 'reader_auto_scroll';
  static const String _keyAutoScrollSpeed = 'reader_auto_scroll_speed';
  static const String _keyLetterSpacing = 'reader_letter_spacing';
  static const String _keyPunctuationSqueeze = 'reader_punctuation_squeeze';
  static const String _keyBaselineAlign = 'reader_baseline_align';

  Future<void> _loadSettings() async {
    theme.value = ReaderTheme.fromId(
      prefs.getString(_keyTheme) ?? ReaderTheme.light.id,
    );
    fontSize.value = ReaderFontSize.fromSize(
      prefs.getDouble(_keyFontSize) ?? ReaderFontSize.medium.size,
    );
    lineHeight.value = prefs.getDouble(_keyLineHeight) ?? 1.6;
    paragraphSpacing.value = prefs.getDouble(_keyParagraphSpacing) ?? 16.0;
    padding.value = prefs.getDouble(_keyPadding) ?? 16.0;
    readerBgColorIndex.value = prefs.getInt(_keyReaderBgColorIndex) ?? 0;
    autoScroll.value = prefs.getBool(_keyAutoScroll) ?? false;
    autoScrollSpeed.value = prefs.getInt(_keyAutoScrollSpeed) ?? 30;
    letterSpacing.value = prefs.getDouble(_keyLetterSpacing) ?? 0.0;
    punctuationSqueeze.value = prefs.getBool(_keyPunctuationSqueeze) ?? true;
    baselineAlign.value = prefs.getBool(_keyBaselineAlign) ?? true;
  }

  Future<void> setTheme(ReaderTheme newTheme) async {
    theme.value = newTheme;
    await prefs.setString(_keyTheme, newTheme.id);
  }

  Future<void> setFontSize(ReaderFontSize newSize) async {
    fontSize.value = newSize;
    await prefs.setDouble(_keyFontSize, newSize.size);
  }

  Future<void> setLineHeight(double value) async {
    lineHeight.value = value;
    await prefs.setDouble(_keyLineHeight, value);
  }

  Future<void> setParagraphSpacing(double value) async {
    paragraphSpacing.value = value;
    await prefs.setDouble(_keyParagraphSpacing, value);
  }

  Future<void> setPadding(double value) async {
    padding.value = value;
    await prefs.setDouble(_keyPadding, value);
  }

  Future<void> setReaderBgColorIndex(int index) async {
    readerBgColorIndex.value = index;
    await prefs.setInt(_keyReaderBgColorIndex, index);
  }

  Future<void> setAutoScroll(bool value) async {
    autoScroll.value = value;
    await prefs.setBool(_keyAutoScroll, value);
  }

  Future<void> setAutoScrollSpeed(int value) async {
    autoScrollSpeed.value = value;
    await prefs.setInt(_keyAutoScrollSpeed, value);
  }

  Future<void> setLetterSpacing(double value) async {
    letterSpacing.value = value;
    await prefs.setDouble(_keyLetterSpacing, value);
  }

  Future<void> setPunctuationSqueeze(bool value) async {
    punctuationSqueeze.value = value;
    await prefs.setBool(_keyPunctuationSqueeze, value);
  }

  Future<void> setBaselineAlign(bool value) async {
    baselineAlign.value = value;
    await prefs.setBool(_keyBaselineAlign, value);
  }

  /// 重置为默认设置
  Future<void> resetToDefault() async {
    await setTheme(ReaderTheme.light);
    await setFontSize(ReaderFontSize.medium);
    await setLineHeight(1.6);
    await setParagraphSpacing(16.0);
    await setPadding(16.0);
    await setReaderBgColorIndex(0);
    await setAutoScroll(false);
    await setAutoScrollSpeed(30);
    await setLetterSpacing(0.0);
    await setPunctuationSqueeze(true);
    await setBaselineAlign(true);
  }
}
