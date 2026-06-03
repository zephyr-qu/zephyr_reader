import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/settings/persisted_signal.dart';
import 'package:zephyr_reader/core/settings/settings_keys.dart';
import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 阅读器翻页点击区域布局
enum TapLayout {
  rightHanded,
  leftHanded;
}
/// 书写方向
enum WritingDirection {
  /// 横排
  horizontal,

  /// 竖排 (top-to-bottom, right-to-left)
  vertical,
}

/// 阅读模式
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


/// 阅读器主题
enum ReaderTheme {
  light('light', '日间'),
  dark('dark', '夜间'),
  sepia('sepia', '护眼');

  final String id;
  final String displayName;

  const ReaderTheme(
    this.id,
    this.displayName,
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

  // ==================== 持久化信号 ====================

  /// 当前主题
  late final theme = persistedEnum<ReaderTheme>(
    prefs, SettingsKeys.readerTheme, ReaderTheme.light, ReaderTheme.fromId,
    debounce: Duration.zero,
  );

  /// 字体大小（存储为 double，通过 [fontSizeValue] 获取实际 [ReaderFontSize] 尺寸）
  late final fontSize = persistedDouble(
    prefs, SettingsKeys.readerFontSize, ReaderFontSize.medium.size,
  );

  /// 行间距
  late final lineHeight = persistedDouble(prefs, SettingsKeys.readerLineHeight, 1.6);

  /// 段落间距
  late final paragraphSpacing = persistedDouble(
    prefs, SettingsKeys.readerParagraphSpacing, 16.0,
  );

  /// 页边距
  late final padding = persistedDouble(prefs, SettingsKeys.readerPadding, 16.0);

  /// 阅读背景色预设索引
  late final readerBgColorIndex = persistedInt(
    prefs, SettingsKeys.readerBgColorIndex, 0,
  );

  /// 是否自动翻页
  late final autoScroll = persistedBool(
    prefs, SettingsKeys.readerAutoScroll, false,
    debounce: Duration.zero,
  );

  /// 自动翻页速度（秒）
  late final autoScrollSpeed = persistedInt(
    prefs, SettingsKeys.readerAutoScrollSpeed, 30,
  );

  /// 字间距
  late final letterSpacing = persistedDouble(
    prefs, SettingsKeys.readerLetterSpacing, 0.0,
  );

  /// 标点挤压
  late final punctuationSqueeze = persistedBool(
    prefs, SettingsKeys.readerPunctuationSqueeze, true,
    debounce: Duration.zero,
  );

  /// 中西文基线对齐
  late final baselineAlign = persistedBool(
    prefs, SettingsKeys.readerBaselineAlign, true,
    debounce: Duration.zero,
  );

  /// 翻页点击区域布局
  late final tapLayout = persistedEnum<TapLayout>(
    prefs, SettingsKeys.readerTapLayout, TapLayout.rightHanded,
    (name) => TapLayout.values.firstWhere(
      (e) => e.name == name,
      orElse: () => TapLayout.rightHanded,
    ),
    debounce: Duration.zero,
  );

  // ==================== 非持久化信号 ====================

  /// 书写方向（横排/竖排，不持久化）
  final writingDirection = signal<WritingDirection>(WritingDirection.horizontal);

  /// 亮度遮罩（0.0–1.0，瞬态不持久化）
  final brightnessOverlay = signal<double>(0.0);

  // ==================== 计算属性 ====================

  /// 页边距兼容别名（→ padding）
  double get pageMargin => padding.value;

  /// 获取实际 [ReaderFontSize] 的尺寸（将存储的 double 四舍五入到最近的档位）
  double get fontSizeValue => ReaderFontSize.fromSize(fontSize.value).size;

  ReaderConfig(this.prefs);

  /// 重置所有设置为默认值
  Future<void> resetToDefault() async {
    theme.value = ReaderTheme.light;
    fontSize.value = ReaderFontSize.medium.size;
    lineHeight.value = 1.6;
    paragraphSpacing.value = 16.0;
    padding.value = 16.0;
    readerBgColorIndex.value = 0;
    autoScroll.value = false;
    autoScrollSpeed.value = 30;
    letterSpacing.value = 0.0;
    punctuationSqueeze.value = true;
    baselineAlign.value = true;
    tapLayout.value = TapLayout.rightHanded;
  }
}
