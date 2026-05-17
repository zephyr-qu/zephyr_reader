import 'package:flutter/material.dart';

/// 阅读器字体配置
///
/// 提供字体栈回退（CJK → Latin → 系统回退）和基线对齐所需的 StrutStyle。
/// 所有阅读器中的文本样式统一从此类获取，避免硬编码。
class FontConfig {
  FontConfig._();

  /// 中文首选字体
  static const String chineseFont = 'Noto Sans SC';

  /// 英文首选字体
  static const String latinFont = 'Roboto';

  /// 回退字体系列（有序：CJK → Latin → 泛型）
  static const List<String> fallbackStack = [
    'PingFang SC',
    'Noto Sans CJK SC',
    'Source Han Sans SC',
    'Microsoft YaHei',
    'SF Pro Text',
    'SF Pro',
    'sans-serif',
  ];

  /// 构建阅读器正文 TextStyle，附带字体栈回退
  static TextStyle readerStyle({
    required double fontSize,
    required double lineHeight,
    required Color color,
    String? fontFamily,
    bool useLatin = false,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontSize: fontSize,
      height: lineHeight,
      color: color,
      fontFamily: fontFamily ?? (useLatin ? latinFont : chineseFont),
      fontFamilyFallback: fallbackStack,
      letterSpacing: letterSpacing,
    );
  }

  /// 构建 StrutStyle，确保中西文混合排版时基线对齐
  static StrutStyle readerStrut({
    required double fontSize,
    required double lineHeight,
    String? fontFamily,
    bool useLatin = false,
  }) {
    return StrutStyle(
      fontFamily: fontFamily ?? (useLatin ? latinFont : chineseFont),
      fontFamilyFallback: fallbackStack,
      fontSize: fontSize * 0.95,
      height: lineHeight,
      forceStrutHeight: true,
    );
  }
}
