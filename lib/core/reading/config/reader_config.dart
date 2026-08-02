import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/settings/persisted_signal.dart';
import 'package:zephyr_reader/core/settings/settings_keys.dart';
import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/local/preferences_service.dart';
import 'package:zephyr_reader/core/reading/config/reader_typography_defaults.dart';

/// 阅读模式 — 上下滚动、左右分页。
enum ReadingMode {
  /// 上下滚动
  scroll,

  /// 左右分页
  pagination,
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
/// 管理阅读页参数，使用 PersistedSignal 自动持久化。
class ReaderConfig {
  final PreferencesService prefs;

  // ==================== 持久化信号 ====================

  /// 当前主题
  late final theme = persistedEnum(
    prefs,
    SettingsKeys.readerTheme,
    ReaderTheme.light,
    ReaderTheme.fromId,
    debounce: Duration.zero,
  );

  /// 字体族
  late final fontFamily = persistedString(
    prefs,
    SettingsKeys.readerFontFamily,
    'System',
  );

  /// 字体大小（Readium 百分比，100 = 不缩放）
  late final fontSize = persistedDouble(
    prefs,
    SettingsKeys.readerFontSize,
    ReaderTypographyDefaults.fontSize,
  );

  /// 页边距
  late final padding = persistedDouble(
    prefs,
    SettingsKeys.readerPadding,
    ReaderTypographyDefaults.padding,
  );

  /// 字重（Readium 支持 100–900，400 = 常规）
  late final fontWeight = persistedDouble(
    prefs,
    SettingsKeys.readerFontWeight,
    ReaderTypographyDefaults.fontWeight,
  );

  /// 阅读模式（分页 / 滚动）
  late final readingMode = persistedEnum(
    prefs,
    SettingsKeys.readerReadingMode,
    ReadingMode.pagination,
    (s) => ReadingMode.values.asNameMap()[s] ?? ReadingMode.pagination,
    debounce: Duration.zero,
  );

  /// 阅读背景色预设索引
  late final readerBgColorIndex = persistedInt(
    prefs,
    SettingsKeys.readerBgColorIndex,
    ReaderTypographyDefaults.readerBgColorIndex,
  );

  /// 是否自动翻页
  late final autoScroll = persistedBool(
    prefs,
    SettingsKeys.readerAutoScroll,
    false,
    debounce: Duration.zero,
  );

  /// 自动翻页速度（秒）
  late final autoScrollSpeed = persistedInt(
    prefs,
    SettingsKeys.readerAutoScrollSpeed,
    30,
  );

  // ==================== 非持久化信号 ====================

  /// 亮度遮罩（0.0–1.0，瞬态不持久化）
  final brightnessOverlay = signal<double>(0.0);

  ReaderConfig(this.prefs);

  /// 重置所有设置为默认值
  void resetToDefault() {
    theme.reset();
    fontSize.reset();
    fontFamily.reset();
    padding.reset();
    fontWeight.reset();
    readingMode.reset();
    readerBgColorIndex.reset();
    autoScroll.reset();
    autoScrollSpeed.reset();
  }

  /// 释放所有 signal 资源。
  void dispose() {
    theme.dispose();
    fontSize.dispose();
    fontFamily.dispose();
    padding.dispose();
    fontWeight.dispose();
    readingMode.dispose();
    readerBgColorIndex.dispose();
    autoScrollSpeed.dispose();
    brightnessOverlay.dispose();
  }
}
