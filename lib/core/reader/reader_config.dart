import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/settings/persisted_signal.dart';
import 'package:zephyr_reader/core/settings/settings_keys.dart';
import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 阅读器翻页点击区域布局（右手/左手习惯）
enum TapLayout { rightHanded, leftHanded }

/// 书写方向 — 横排或竖排（top-to-bottom, right-to-left）
enum WritingDirection {
  /// 横排
  horizontal,

  /// 竖排 (top-to-bottom, right-to-left)
  vertical,
}

/// 阅读模式 — 上下滚动、仿真翻页、左右分页、双语对照
enum ReadingMode {
  /// 上下滚动
  scroll,

  /// 仿真翻页
  pageTurn,

  /// 左右分页
  pagination,

  /// 双语对照
  bilingual,
}

/// 阅读器主题 — 亮色、深色、护眼色
enum ReaderTheme {
  light('light'),
  dark('dark'),
  sepia('sepia');

  final String id;

  const ReaderTheme(this.id);

  static ReaderTheme fromId(String id) {
    return ReaderTheme.values.firstWhere(
      (theme) => theme.id == id,
      orElse: () => ReaderTheme.light,
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
/// 阅读器配置
///
/// 管理阅读页的所有用户可调参数，包括主题、字体、布局、翻页等。
/// 使用 PersistedSignal 实现自动持久化，支持重置为默认值。
class ReaderConfig {
  final SharedPreferences prefs;

  // ==================== 持久化信号 ====================

  /// 当前主题
  late final theme = persisted<ReaderTheme>(
    prefs,
    SettingsKeys.readerTheme,
    ReaderTheme.light,
    reader: (p, k) => readEnum(p, k, ReaderTheme.light, ReaderTheme.fromId),
    writer: (p, k, v) => p.setString(k, v.name),
    debounce: Duration.zero,
  );

  /// 字体大小
  late final fontSize = persisted<double>(
    prefs,
    SettingsKeys.readerFontSize,
    16.0,
    reader: (p, k) => p.getDouble(k) ?? 16.0,
    writer: (p, k, v) => p.setDouble(k, v),
  );

  /// 行间距
  late final lineHeight = persisted<double>(
    prefs,
    SettingsKeys.readerLineHeight,
    1.6,
    reader: (p, k) => p.getDouble(k) ?? 1.6,
    writer: (p, k, v) => p.setDouble(k, v),
  );

  /// 段落间距
  late final paragraphSpacing = persisted<double>(
    prefs,
    SettingsKeys.readerParagraphSpacing,
    16.0,
    reader: (p, k) => p.getDouble(k) ?? 16.0,
    writer: (p, k, v) => p.setDouble(k, v),
  );

  /// 页边距
  late final padding = persisted<double>(
    prefs,
    SettingsKeys.readerPadding,
    16.0,
    reader: (p, k) => p.getDouble(k) ?? 16.0,
    writer: (p, k, v) => p.setDouble(k, v),
  );

  /// 阅读背景色预设索引
  late final readerBgColorIndex = persisted<int>(
    prefs,
    SettingsKeys.readerBgColorIndex,
    0,
    reader: (p, k) => p.getInt(k) ?? 0,
    writer: (p, k, v) => p.setInt(k, v),
  );

  /// 是否自动翻页
  late final autoScroll = persisted<bool>(
    prefs,
    SettingsKeys.readerAutoScroll,
    false,
    reader: (p, k) => p.getBool(k) ?? false,
    writer: (p, k, v) => p.setBool(k, v),
    debounce: Duration.zero,
  );

  /// 自动翻页速度（秒）
  late final autoScrollSpeed = persisted<int>(
    prefs,
    SettingsKeys.readerAutoScrollSpeed,
    30,
    reader: (p, k) => p.getInt(k) ?? 30,
    writer: (p, k, v) => p.setInt(k, v),
  );

  /// 字间距
  late final letterSpacing = persisted<double>(
    prefs,
    SettingsKeys.readerLetterSpacing,
    0.0,
    reader: (p, k) => p.getDouble(k) ?? 0.0,
    writer: (p, k, v) => p.setDouble(k, v),
  );

  /// 标点挤压
  late final punctuationSqueeze = persisted<bool>(
    prefs,
    SettingsKeys.readerPunctuationSqueeze,
    true,
    reader: (p, k) => p.getBool(k) ?? true,
    writer: (p, k, v) => p.setBool(k, v),
    debounce: Duration.zero,
  );

  /// 中西文基线对齐
  late final baselineAlign = persisted<bool>(
    prefs,
    SettingsKeys.readerBaselineAlign,
    true,
    reader: (p, k) => p.getBool(k) ?? true,
    writer: (p, k, v) => p.setBool(k, v),
    debounce: Duration.zero,
  );

  late final textAlign = persisted<TextAlign>(
    prefs,
    SettingsKeys.readerTextAlign,
    TextAlign.justify,
    reader: (p, k) => readEnum(p, k, TextAlign.justify, (name) => TextAlign.values.firstWhere(
      (e) => e.name == name,
      orElse: () => TextAlign.justify,
    )),
    writer: (p, k, v) => p.setString(k, v.name),
    debounce: Duration.zero,
  );

  /// 翻页点击区域布局
  late final tapLayout = persisted<TapLayout>(
    prefs,
    SettingsKeys.readerTapLayout,
    TapLayout.rightHanded,
    reader: (p, k) => readEnum(p, k, TapLayout.rightHanded, (name) => TapLayout.values.firstWhere(
      (e) => e.name == name,
      orElse: () => TapLayout.rightHanded,
    )),
    writer: (p, k, v) => p.setString(k, v.name),
    debounce: Duration.zero,
  );

  /// 是否跟随系统字体缩放（而非仅阅读器自有字号）
  late final followSystemFontScale = persisted<bool>(
    prefs,
    SettingsKeys.readerFollowSystemFontScale,
    false,
    reader: (p, k) => p.getBool(k) ?? false,
    writer: (p, k, v) => p.setBool(k, v),
    debounce: Duration.zero,
  );

  // ==================== 非持久化信号 ====================

  /// 书写方向（横排/竖排，不持久化）
  final writingDirection = signal<WritingDirection>(
    WritingDirection.horizontal,
  );

  /// 亮度遮罩（0.0–1.0，瞬态不持久化）
  final brightnessOverlay = signal<double>(0.0);

  // ==================== 计算属性 ====================

  /// 页边距兼容别名（→ padding）
  double get pageMargin => padding.value;

  ReaderConfig(this.prefs);

  /// 重置所有设置为默认值
  void resetToDefault() {
    theme.reset();
    fontSize.reset();
    lineHeight.reset();
    paragraphSpacing.reset();
    padding.reset();
    readerBgColorIndex.reset();
    autoScroll.reset();
    autoScrollSpeed.reset();
    letterSpacing.reset();
    punctuationSqueeze.reset();
    baselineAlign.reset();
    tapLayout.reset();
    textAlign.reset();
  }

  /// 释放所有 signal 资源。
  void dispose() {
    theme.dispose();
    fontSize.dispose();
    lineHeight.dispose();
    paragraphSpacing.dispose();
    padding.dispose();
    readerBgColorIndex.dispose();
    autoScroll.dispose();
    autoScrollSpeed.dispose();
    letterSpacing.dispose();
    punctuationSqueeze.dispose();
    baselineAlign.dispose();
    tapLayout.dispose();
    followSystemFontScale.dispose();
    textAlign.dispose();
    writingDirection.dispose();
    brightnessOverlay.dispose();
  }
}
