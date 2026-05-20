import 'package:flutter/material.dart';

class FontConfig {
  FontConfig._();

  static const String chineseFont = 'Noto Sans SC';
  static const String latinFont = 'Roboto';

  static const List<String> fallbackStack = ['sans-serif'];

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
