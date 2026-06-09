import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/settings/persisted_signal.dart';
import 'package:zephyr_reader/core/settings/settings_keys.dart';
import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
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


extension ReaderThemeX on ReaderTheme {
  String l10nLabel(AppLocalizations l10n) => switch (this) {
    ReaderTheme.light => l10n.readerThemeLight,
    ReaderTheme.dark => l10n.readerThemeDark,
    ReaderTheme.sepia => l10n.readerThemeSepia,
  };
}

extension TapLayoutX on TapLayout {
  String l10nLabel(AppLocalizations l10n) => switch (this) {
    TapLayout.rightHanded => l10n.tapLayoutRightHanded,
    TapLayout.leftHanded => l10n.tapLayoutLeftHanded,
  };
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
  late final theme = persistedEnum<ReaderTheme>(
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
    16.0,
  );

  /// 行间距
  late final lineHeight = persistedDouble(
    prefs,
    SettingsKeys.readerLineHeight,
    1.6,
  );

  /// 段落间距
  late final paragraphSpacing = persistedDouble(
    prefs,
    SettingsKeys.readerParagraphSpacing,
    16.0,
  );

  /// 页边距
  late final padding = persistedDouble(prefs, SettingsKeys.readerPadding, 16.0);

  /// 阅读背景色预设索引
  late final readerBgColorIndex = persistedInt(
    prefs,
    SettingsKeys.readerBgColorIndex,
    0,
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

  /// 中西文基线对齐
  late final baselineAlign = persistedBool(
    prefs,
    SettingsKeys.readerBaselineAlign,
    true,
    debounce: Duration.zero,
  );

  /// 翻页点击区域布局
  late final tapLayout = persistedEnum<TapLayout>(
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
    writingDirection.dispose();
    brightnessOverlay.dispose();
  }
}
