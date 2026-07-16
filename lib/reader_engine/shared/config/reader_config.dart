import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/settings/persisted_signal.dart';
import 'package:zephyr_reader/core/settings/settings_keys.dart';
import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/local/preferences_service.dart';
import 'package:zephyr_reader/reader_engine/shared/config/reader_typography_defaults.dart';
import 'package:zephyr_reader/reader_engine/shared/config/reading_mode_utils.dart';
import 'package:zephyr_reader/reader_engine/shared/config/language_type.dart';

/// 阅读器翻页点击区域布局（右手/左手习惯）
enum TapLayout { rightHanded, leftHanded }

/// 阅读模式 — 上下滚动、左右分页、双语对照。
/// 卷曲翻页见 [PaginationSkin]（ADR-002，非独立模式）。
enum ReadingMode {
  /// 上下滚动
  scroll,

  /// 左右分页（配合 [PaginationSkin]）
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

  /// 字体大小
  late final fontSize = persistedDouble(
    prefs,
    SettingsKeys.readerFontSize,
    ReaderTypographyDefaults.fontSize,
  );

  /// 行间距
  late final lineHeight = persistedDouble(
    prefs,
    SettingsKeys.readerLineHeight,
    ReaderTypographyDefaults.lineHeight,
  );

  /// 段落间距
  late final paragraphSpacing = persistedDouble(
    prefs,
    SettingsKeys.readerParagraphSpacing,
    ReaderTypographyDefaults.paragraphSpacing,
  );

  /// 页边距
  late final padding = persistedDouble(
    prefs,
    SettingsKeys.readerPadding,
    ReaderTypographyDefaults.padding,
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

  /// 字间距
  late final letterSpacing = persistedDouble(
    prefs,
    SettingsKeys.readerLetterSpacing,
    0.0,
  );

  /// 标点挤压
  late final punctuationSqueeze = persistedBool(
    prefs,
    SettingsKeys.readerPunctuationSqueeze,
    true,
    debounce: Duration.zero,
  );

  late final baselineAlign = persistedBool(
    prefs,
    SettingsKeys.readerBaselineAlign,
    true,
    debounce: Duration.zero,
  );

  /// 首行缩进
  late final firstLineIndent = persistedBool(
    prefs,
    SettingsKeys.readerFirstLineIndent,
    true,
    debounce: Duration.zero,
  );

  /// 语言类型
  late final language = persistedEnum<LanguageType>(
    prefs,
    SettingsKeys.readerLanguage,
    LanguageType.auto,
    (name) => LanguageType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => LanguageType.auto,
    ),
    debounce: Duration.zero,
  );

  /// 中西文自动间距比例（相对于 font_size，0.0 ~ 1.0）
  late final autoSpaceRatio = persistedDouble(
    prefs,
    SettingsKeys.readerAutoSpaceRatio,
    0.25,
    debounce: Duration.zero,
  );

  late final textAlign = persistedEnum(
    prefs,
    SettingsKeys.readerTextAlign,
    TextAlign.justify,
    (name) => TextAlign.values.firstWhere(
      (e) => e.name == name,
      orElse: () => TextAlign.justify,
    ),
    debounce: Duration.zero,
  );

  /// pagination 翻页动画：滑动 / 卷曲（ADR-002）
  late final paginationSkin = persistedEnum(
    prefs,
    SettingsKeys.readerPaginationSkin,
    PaginationSkin.slide,
    (name) => PaginationSkin.values.firstWhere(
      (e) => e.name == name,
      orElse: () => PaginationSkin.slide,
    ),
    debounce: Duration.zero,
  );

  /// 翻页点击区域布局
  late final tapLayout = persistedEnum(
    prefs,
    SettingsKeys.readerTapLayout,
    TapLayout.rightHanded,
    (name) => TapLayout.values.firstWhere(
      (e) => e.name == name,
      orElse: () => TapLayout.rightHanded,
    ),
    debounce: Duration.zero,
  );

  /// 是否跟随系统字体缩放（而非仅阅读器自有字号）
  late final followSystemFontScale = persistedBool(
    prefs,
    SettingsKeys.readerFollowSystemFontScale,
    false,
    debounce: Duration.zero,
  );

  // ==================== 非持久化信号 ====================

  /// 亮度遮罩（0.0–1.0，瞬态不持久化）
  final brightnessOverlay = signal<double>(0.0);

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
    baselineAlign.reset();
    autoSpaceRatio.reset();
    firstLineIndent.reset();
    language.reset();
    tapLayout.reset();
  }

  /// 释放所有 signal 资源。
  void dispose() {
    theme.dispose();
    fontSize.dispose();
    lineHeight.dispose();
    paragraphSpacing.dispose();
    padding.dispose();
    readerBgColorIndex.dispose();
    autoScrollSpeed.dispose();
    letterSpacing.dispose();
    punctuationSqueeze.dispose();
    firstLineIndent.dispose();
    autoSpaceRatio.dispose();
    baselineAlign.dispose();
    language.dispose();
    tapLayout.dispose();
    followSystemFontScale.dispose();
    textAlign.dispose();
    paginationSkin.dispose();
    brightnessOverlay.dispose();
  }
}
