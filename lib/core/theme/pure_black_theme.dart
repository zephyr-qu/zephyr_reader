library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PureBlackTheme {
  static const Color backgroundColor = Color(0xFF000000);

  static const Color surfaceColor = Color(0xFF0A0A0A);

  static const Color borderColor = Color(0xFF1A1A1A);

  static const Color textPrimary = Color(0xFFFFFFFF);

  static const Color textSecondary = Color(0xFF9CA3AF);

  static const Color primary = Color(0xFF5EEAD4);

  static const Color primaryContainer = Color(0xFF115E59);

  static const Color error = Color(0xFFF87171);

  static ThemeData buildTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: backgroundColor,
      cardColor: surfaceColor,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        onPrimary: Color(0xFF134E4A),
        primaryContainer: primaryContainer,
        onPrimaryContainer: Color(0xFFCCFBF1),
        secondary: Color(0xFFFDA4AF),
        onSecondary: Color(0xFF881337),
        secondaryContainer: Color(0xFF9F1239),
        onSecondaryContainer: Color(0xFFFFE4E6),
        tertiary: Color(0xFFC4B5FD),
        onTertiary: Color(0xFF4C1D95),
        tertiaryContainer: Color(0xFF5B21B6),
        onTertiaryContainer: Color(0xFFEDE9FE),
        error: error,
        onError: Color(0xFF991B1B),
        errorContainer: Color(0xFFB91C1C),
        onErrorContainer: Color(0xFFFEE2E2),
        surface: surfaceColor,
        onSurface: textPrimary,
        surfaceContainerHighest: Color(0xFF1A1A1A),
        onSurfaceVariant: textSecondary,
        outline: Color(0xFF334155),
        outlineVariant: Color(0xFF1E293B),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
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
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderColor, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return primary;
            }
            if (states.contains(WidgetState.disabled)) {
              return borderColor;
            }
            return primary;
          }),
          foregroundColor: WidgetStateProperty.all(const Color(0xFF134E4A)),
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
          borderSide: const BorderSide(color: error, width: 1),
        ),
        hintStyle: const TextStyle(color: textSecondary),
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
        elevation: 1,
        indicatorColor: surfaceColor,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primary,
            );
          }
          return const TextStyle(fontSize: 12, color: textSecondary);
        }),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: backgroundColor,
        indicatorColor: surfaceColor,
        selectedIconTheme: IconThemeData(color: primary, size: 24),
        unselectedIconTheme: IconThemeData(color: textSecondary, size: 22),
        selectedLabelTextStyle: TextStyle(
          color: primary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        unselectedLabelTextStyle: TextStyle(color: textSecondary, fontSize: 13),
      ),
    );
  }

  /// 纯黑主题预览
  static Widget buildPreview() {
    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '纯黑主题',
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
