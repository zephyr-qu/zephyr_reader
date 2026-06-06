import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';

/// 语义化菜单项颜色枚举
///
/// 每个成员提供 [iconColor] 和 [iconBackground] 方法，根据 [Brightness]
/// 返回适配亮暗模式的颜色值。
enum MenuItemSemantic {
  info,
  warning,
  success,
  experimental,
  reading,
  neutral,
  legal,
  education,
  about,
  error,
  primary,
  typography;

  Color iconColor(Brightness brightness) => switch (this) {
    MenuItemSemantic.info =>
      brightness == Brightness.dark
          ? const Color(0xFF64B5F6)
          : const Color(0xFF2196F3),
    MenuItemSemantic.warning => DesignTokens.warning,
    MenuItemSemantic.success => DesignTokens.success,
    MenuItemSemantic.experimental =>
      brightness == Brightness.dark
          ? const Color(0xFF9575CD)
          : const Color(0xFF673AB7),
    MenuItemSemantic.reading =>
      brightness == Brightness.dark
          ? const Color(0xFF4DB6AC)
          : const Color(0xFF009688),
    MenuItemSemantic.neutral =>
      brightness == Brightness.dark
          ? const Color(0xFFBDBDBD)
          : const Color(0xFF9E9E9E),
    MenuItemSemantic.legal =>
      brightness == Brightness.dark
          ? const Color(0xFF7986CB)
          : const Color(0xFF3F51B5),
    MenuItemSemantic.education =>
      brightness == Brightness.dark
          ? const Color(0xFFB39DDB)
          : const Color(0xFF673AB7),
    MenuItemSemantic.about =>
      brightness == Brightness.dark
          ? const Color(0xFF90A4AE)
          : const Color(0xFF607D8B),
    MenuItemSemantic.error => DesignTokens.error,
    MenuItemSemantic.primary =>
      brightness == Brightness.dark
          ? const Color(0xFF82B1FF)
          : const Color(0xFF448AFF),
    MenuItemSemantic.typography =>
      brightness == Brightness.dark
          ? const Color(0xFF8C9EFF)
          : const Color(0xFF536DFE),
  };

  Color iconBackground(Brightness brightness) =>
      iconColor(brightness).withValues(alpha: 0.12);
}
