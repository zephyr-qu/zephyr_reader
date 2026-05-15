import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/theme/theme_extension.dart';

class AppThemes {
  AppThemes._();

  static ThemeData get lightTheme => _buildLightTheme();
  static ThemeData get darkTheme => _buildDarkTheme();

  static ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: DesignTokens.background,
      colorScheme: _lightColorScheme,
      textTheme: _textTheme(
        onSurface: DesignTokens.textPrimary,
        onSurfaceVariant: DesignTokens.textSecondary,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: DesignTokens.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: DesignTokens.textPrimary,
          letterSpacing: -0.5,
        ),
      ),

      cardTheme: const CardThemeData(
        color: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(DesignTokens.primary),
          foregroundColor: WidgetStateProperty.all(DesignTokens.onPrimary),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
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
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          side: WidgetStateProperty.all(
            const BorderSide(color: DesignTokens.divider, width: 0.5),
          ),
          foregroundColor: WidgetStateProperty.all(DesignTokens.textPrimary),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(DesignTokens.primary),
          padding: WidgetStateProperty.all(EdgeInsets.zero),
          minimumSize: WidgetStateProperty.all(Size.zero),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DesignTokens.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: DesignTokens.divider, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: DesignTokens.divider, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: DesignTokens.primary, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: DesignTokens.error, width: 0.5),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: DesignTokens.divider, width: 0.5),
        ),
        elevation: 0,
        color: DesignTokens.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),

      listTileTheme: const ListTileThemeData(
        minTileHeight: 44,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        dense: true,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: DesignTokens.textPrimary,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: 13,
          color: DesignTokens.textSecondary,
        ),
        iconColor: DesignTokens.textSecondary,
      ),

      iconTheme: const IconThemeData(size: 22, color: DesignTokens.textSecondary),
      chipTheme: const ChipThemeData(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        labelStyle: TextStyle(fontSize: 12, color: DesignTokens.textPrimary),
        backgroundColor: Colors.transparent,
        elevation: 0,
        side: BorderSide(color: DesignTokens.divider, width: 0.5),
      ),

      dividerTheme: const DividerThemeData(
        thickness: 0.5,
        color: DesignTokens.divider,
        space: 0,
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        elevation: 0,
        backgroundColor: DesignTokens.surface,
        selectedItemColor: DesignTokens.primary,
        unselectedItemColor: DesignTokens.textSecondary,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),

      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: DesignTokens.surface,
        indicatorColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w500, color: DesignTokens.primary,
            );
          }
          return const TextStyle(
            fontSize: 11, color: DesignTokens.textSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(size: 22, color: DesignTokens.primary);
          }
          return const IconThemeData(size: 22, color: DesignTokens.textSecondary);
        }),
      ),

      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        selectedIconTheme: IconThemeData(size: 22, color: DesignTokens.primary),
        unselectedIconTheme: IconThemeData(size: 22, color: DesignTokens.textSecondary),
        selectedLabelTextStyle: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w500, color: DesignTokens.primary,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontSize: 12, color: DesignTokens.textSecondary,
        ),
      ),

      sliderTheme: const SliderThemeData(
        trackHeight: 2,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
        activeTrackColor: DesignTokens.primary,
        inactiveTrackColor: DesignTokens.divider,
        thumbColor: DesignTokens.primary,
        overlayColor: Color(0x1A07D2D7),
      ),

      extensions: const [
        AppThemeExtension(
          primaryContainer: DesignTokens.primaryContainer,
          secondaryContainer: DesignTokens.secondary,
          surfaceVariant: DesignTokens.surface,
          shadow: BoxShadow(
            blurRadius: 0,
            color: Colors.transparent,
            offset: Offset(0, 0),
          ),
        ),
      ],
    );
  }

  static ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: DesignTokens.backgroundDark,
      colorScheme: _darkColorScheme,
      textTheme: _textTheme(
        onSurface: DesignTokens.textPrimaryDark,
        onSurfaceVariant: DesignTokens.textSecondaryDark,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: DesignTokens.textPrimaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: DesignTokens.textPrimaryDark,
          letterSpacing: -0.5,
        ),
      ),

      cardTheme: const CardThemeData(
        color: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(DesignTokens.primary),
          foregroundColor: WidgetStateProperty.all(const Color(0xFF003B3B)),
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
          side: WidgetStateProperty.all(
            const BorderSide(color: DesignTokens.dividerDark, width: 0.5),
          ),
          foregroundColor: WidgetStateProperty.all(DesignTokens.textPrimaryDark),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(DesignTokens.primary),
          padding: WidgetStateProperty.all(EdgeInsets.zero),
          minimumSize: WidgetStateProperty.all(Size.zero),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DesignTokens.surfaceDark,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: DesignTokens.dividerDark, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: DesignTokens.dividerDark, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: DesignTokens.primary, width: 1),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: DesignTokens.dividerDark, width: 0.5),
        ),
        elevation: 0,
        color: DesignTokens.surfaceDark,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),

      listTileTheme: const ListTileThemeData(
        minTileHeight: 44,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        dense: true,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: DesignTokens.textPrimaryDark,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: 13,
          color: DesignTokens.textSecondaryDark,
        ),
        iconColor: DesignTokens.textSecondaryDark,
      ),

      iconTheme: const IconThemeData(size: 22, color: DesignTokens.textSecondaryDark),
      chipTheme: const ChipThemeData(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        labelStyle: TextStyle(fontSize: 12, color: DesignTokens.textPrimaryDark),
        backgroundColor: Colors.transparent,
        elevation: 0,
        side: BorderSide(color: DesignTokens.dividerDark, width: 0.5),
      ),

      dividerTheme: const DividerThemeData(
        thickness: 0.5,
        color: DesignTokens.dividerDark,
        space: 0,
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        elevation: 0,
        backgroundColor: DesignTokens.surfaceDark,
        selectedItemColor: DesignTokens.primary,
        unselectedItemColor: DesignTokens.textSecondaryDark,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),

      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: DesignTokens.surfaceDark,
        indicatorColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w500, color: DesignTokens.primary,
            );
          }
          return const TextStyle(
            fontSize: 11, color: DesignTokens.textSecondaryDark,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(size: 22, color: DesignTokens.primary);
          }
          return const IconThemeData(size: 22, color: DesignTokens.textSecondaryDark);
        }),
      ),

      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        selectedIconTheme: IconThemeData(size: 22, color: DesignTokens.primary),
        unselectedIconTheme: IconThemeData(size: 22, color: DesignTokens.textSecondaryDark),
        selectedLabelTextStyle: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w500, color: DesignTokens.primary,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontSize: 12, color: DesignTokens.textSecondaryDark,
        ),
      ),

      sliderTheme: const SliderThemeData(
        trackHeight: 2,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
        activeTrackColor: DesignTokens.primary,
        inactiveTrackColor: DesignTokens.dividerDark,
        thumbColor: DesignTokens.primary,
        overlayColor: Color(0x1A07D2D7),
      ),

      extensions: const [
        AppThemeExtension(
          primaryContainer: Color(0xFF004D4D),
          secondaryContainer: Color(0xFF4DD0E1),
          surfaceVariant: DesignTokens.surfaceDark,
          shadow: BoxShadow(
            blurRadius: 0,
            color: Colors.transparent,
            offset: Offset(0, 0),
          ),
        ),
      ],
    );
  }

  static const ColorScheme _lightColorScheme = ColorScheme.light(
    primary: DesignTokens.primary,
    onPrimary: DesignTokens.onPrimary,
    primaryContainer: DesignTokens.primaryContainer,
    onPrimaryContainer: DesignTokens.onPrimaryContainer,
    secondary: DesignTokens.secondary,
    tertiary: DesignTokens.tertiary,
    error: DesignTokens.error,
    surface: DesignTokens.background,
    onSurface: DesignTokens.textPrimary,
    onSurfaceVariant: DesignTokens.textSecondary,
    outline: DesignTokens.divider,
    outlineVariant: DesignTokens.divider,
  );

  static const ColorScheme _darkColorScheme = ColorScheme.dark(
    primary: DesignTokens.primary,
    onPrimary: Color(0xFF003B3B),
    primaryContainer: Color(0xFF004D4D),
    onPrimaryContainer: Color(0xFFD2FAFB),
    secondary: Color(0xFF4DD0E1),
    tertiary: Color(0xFF80CBC4),
    error: Color(0xFFEF5350),
    surface: DesignTokens.backgroundDark,
    onSurface: DesignTokens.textPrimaryDark,
    onSurfaceVariant: DesignTokens.textSecondaryDark,
    outline: DesignTokens.dividerDark,
    outlineVariant: DesignTokens.dividerDark,
  );

  static TextTheme _textTheme({
    required Color onSurface,
    required Color onSurfaceVariant,
  }) {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 32, fontWeight: FontWeight.w700,
        color: onSurface, letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        fontSize: 28, fontWeight: FontWeight.w600,
        color: onSurface, letterSpacing: -0.3,
      ),
      headlineLarge: TextStyle(
        fontSize: 24, fontWeight: FontWeight.w700,
        color: onSurface, letterSpacing: -0.3,
      ),
      headlineMedium: TextStyle(
        fontSize: 20, fontWeight: FontWeight.w600,
        color: onSurface, letterSpacing: -0.2,
      ),
      titleLarge: TextStyle(
        fontSize: 18, fontWeight: FontWeight.w600,
        color: onSurface, letterSpacing: -0.2,
      ),
      titleMedium: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w500,
        color: onSurface,
      ),
      bodyLarge: TextStyle(
        fontSize: 15, color: onSurface, height: 1.6,
      ),
      bodyMedium: TextStyle(
        fontSize: 13, color: onSurfaceVariant, height: 1.5,
      ),
      labelLarge: TextStyle(
        fontSize: 12, color: onSurfaceVariant,
        fontWeight: FontWeight.w500, letterSpacing: 0.2,
      ),
    );
  }
}
