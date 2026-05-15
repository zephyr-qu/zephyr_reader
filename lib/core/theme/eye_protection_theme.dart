/// 护眼主题
///
/// 米黄色背景，柔和绿色主色，减少蓝光伤
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 护眼主题数据
class EyeProtectionTheme {
  /// 米黄色背
  static const Color backgroundColor = Color(0xFFFAF9F5);

  /// 浅米色卡
  static const Color surfaceColor = Color(0xFFF5F4F0);

  /// 深褐色文字（比纯黑柔和）
  static const Color textPrimary = Color(0xFF4A4A4A);

  /// 次要文字
  static const Color textSecondary = Color(0xFF6B7280);

  /// 主色（柔和绿
  static const Color primary = Color(0xFF07D2D7);

  static const Color primaryDark = Color(0xFF00979C);

  static const Color primaryContainer = Color(0xFFD2FAFB);

  /// 成功
  static const Color success = Color(0xFF10B981);

  /// 构建护眼主题
  static ThemeData buildTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: backgroundColor,
      cardColor: surfaceColor,
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: textPrimary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: primaryDark,
        secondary: Color(0xFFFB7185),
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFFFE4E6),
        onSecondaryContainer: Color(0xFF881337),
        tertiary: Color(0xFFA78BFA),
        onTertiary: Colors.white,
        tertiaryContainer: Color(0xFFEDE9FE),
        onTertiaryContainer: Color(0xFF4C1D95),
        error: Color(0xFFEF4444),
        onError: Colors.white,
        errorContainer: Color(0xFFFEE2E2),
        onErrorContainer: Color(0xFF991B1B),
        surface: surfaceColor,
        onSurface: textPrimary,
        surfaceContainerHighest: backgroundColor,
        onSurfaceVariant: textSecondary,
        outline: Color(0xFFCBD5E1),
        outlineVariant: Color(0xFFE2E8F0),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 2,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return primaryDark;
            }
            if (states.contains(WidgetState.disabled)) {
              return const Color(0xFFCBD5E1);
            }
            return primary;
          }),
          foregroundColor: WidgetStateProperty.all(textPrimary),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
        ),
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: textPrimary,
        iconColor: textSecondary,
      ),
      iconTheme: const IconThemeData(
        size: 22,
        opacity: 0.9,
        color: textSecondary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: backgroundColor,
        elevation: 2,
        indicatorColor: primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primaryDark,
            );
          }
          return const TextStyle(fontSize: 12, color: textSecondary);
        }),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: backgroundColor,
        indicatorColor: primaryContainer,
        selectedIconTheme: IconThemeData(color: primaryDark, size: 24),
        unselectedIconTheme: IconThemeData(color: textSecondary, size: 22),
        selectedLabelTextStyle: TextStyle(
          color: primaryDark,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        unselectedLabelTextStyle: TextStyle(color: textSecondary, fontSize: 13),
      ),
    );
  }

  /// 获取护眼主题预览
  static Widget buildPreview() {
    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '护眼主题',
            style: TextStyle(color: textPrimary, fontSize: 20),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            color: surfaceColor,
            child: const Text('卡片背景', style: TextStyle(color: textSecondary)),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: () {}, child: const Text('按钮')),
        ],
      ),
    );
  }
}
