import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/theme/theme_extension.dart';
import 'package:zephyr_reader/core/utils/color_utils.dart';

class AppThemes {
  AppThemes._();

  // ===== Light mode base colors =====
  static const Color _bgLight = Color(0xFFFAFAFA);
  static const Color _surfaceLight = Color(0xFFFFFFFF);
  static const Color _textPriLight = Color(0xFF1A1A1A);
  static const Color _textSecLight = Color(0xFF8A8A8E);
  static const Color _dividerLight = Color(0xFFE5E5EA);

  // ===== Dark mode base colors =====
  static const Color _bgDark = Color(0xFF000000);
  static const Color _surfaceDark = Color(0xFF080808);
  static const Color _textPriDark = Color(0xFFF2F2F2);
  static const Color _textSecDark = Color(0xFF6E6E73);
  static const Color _dividerDark = Color(0xFF1C1C1E);

  static ThemeData buildTheme(Brightness brightness, {Color? customPrimary}) {
    final primary = customPrimary ?? DesignTokens.primary;
    final onPrimary = contrastingTextColor(primary);
    final isDark = brightness == Brightness.dark;

    final Color scaffoldBg = isDark ? _bgDark : _bgLight;
    final Color textPri = isDark ? _textPriDark : _textPriLight;
    final Color textSec = isDark ? _textSecDark : _textSecLight;
    final Color surf = isDark ? _surfaceDark : _surfaceLight;
    final Color div = isDark ? _dividerDark : _dividerLight;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: brightness,
        primary: primary,
        onPrimary: onPrimary,
        secondary: DesignTokens.secondary,
        tertiary: DesignTokens.tertiary,
        error: DesignTokens.error,
        surface: isDark ? _bgDark : _bgLight,
        onSurface: isDark ? _textPriDark : _textPriLight,
        onSurfaceVariant: isDark ? _textSecDark : _textSecLight,
        outline: isDark ? _dividerDark : _dividerLight,
        outlineVariant: isDark ? _dividerDark : _dividerLight,
      ),
      textTheme: _textTheme(onSurface: textPri, onSurfaceVariant: textSec),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPri,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: isDark
            ? const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
              )
            : const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark,
              ),
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPri,
          letterSpacing: -0.5,
        ),
      ),

      cardTheme: const CardThemeData(
        color: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(primary),
          foregroundColor: WidgetStateProperty.all(onPrimary),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          elevation: WidgetStateProperty.all(0),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          side: WidgetStateProperty.all(BorderSide(color: div, width: 0.5)),
          foregroundColor: WidgetStateProperty.all(textPri),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(foregroundColor: WidgetStateProperty.all(primary)),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? _surfaceDark : _bgLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: div, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: div, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primary, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: DesignTokens.error, width: 0.5),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: div, width: 0.5),
        ),
        elevation: 0,
        color: surf,
        surfaceTintColor: Colors.transparent,
      ),

      listTileTheme: ListTileThemeData(
        minTileHeight: 44,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        dense: true,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPri,
        ),
        subtitleTextStyle: TextStyle(fontSize: 13, color: textSec),
        iconColor: textSec,
      ),

      iconTheme: IconThemeData(size: 22, color: textSec),
      chipTheme: ChipThemeData(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        labelStyle: TextStyle(fontSize: 12, color: textPri),
        backgroundColor: Colors.transparent,
        elevation: 0,
        side: BorderSide(color: div, width: 0.5),
      ),

      dividerTheme: DividerThemeData(thickness: 0.5, color: div, space: 0),

      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: surf,
        indicatorColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: primary,
            );
          }
          return TextStyle(fontSize: 12, color: textSec);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(size: 22, color: primary);
          }
          return IconThemeData(size: 22, color: textSec);
        }),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        selectedIconTheme: IconThemeData(size: 22, color: primary),
        unselectedIconTheme: IconThemeData(size: 22, color: textSec),
        selectedLabelTextStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: primary,
        ),
        unselectedLabelTextStyle: TextStyle(fontSize: 12, color: textSec),
      ),

      sliderTheme: SliderThemeData(
        trackHeight: 2,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        activeTrackColor: primary,
        inactiveTrackColor: div,
        thumbColor: primary,
        overlayColor: primary.withValues(alpha: 0.1),
      ),

      extensions: [
        AppThemeExtension(
          primaryContainer: DesignTokens.primaryContainer,
          secondaryContainer: DesignTokens.secondary,
          surfaceVariant: surf,
          shadow: DesignTokens.cardShadow,
          dividerSubtle: DesignTokens.dividerSubtle,
          overlayLight: textPri.withValues(alpha: 0.05),
          overlayMedium: textPri.withValues(alpha: 0.08),
        ),
        if (isDark)
          ReaderThemeExtension.dark()
        else
          ReaderThemeExtension.light(),
      ],
    );
  }

  static TextTheme _textTheme({
    required Color onSurface,
    required Color onSurfaceVariant,
  }) {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: onSurface,
        letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: onSurface,
        letterSpacing: -0.3,
      ),
      headlineLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: onSurface,
        letterSpacing: -0.3,
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: onSurface,
        letterSpacing: -0.2,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: onSurface,
        letterSpacing: -0.2,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: onSurface,
      ),
      bodyLarge: TextStyle(fontSize: 15, color: onSurface, height: 1.6),
      bodyMedium: TextStyle(fontSize: 13, color: onSurfaceVariant, height: 1.5),
      labelLarge: TextStyle(
        fontSize: 12,
        color: onSurfaceVariant,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
      ),
      labelSmall: TextStyle(
        fontSize: 10,
        color: onSurfaceVariant,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}
