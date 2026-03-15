import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/theme/theme_extension.dart';

class AppThemes {
  AppThemes._();

  /// 亮色主题
  static ThemeData get lightTheme => _buildLightTheme();

  /// 暗色主题
  static ThemeData get darkTheme => _buildDarkTheme();
  static ThemeData _buildLightTheme() {
    return ThemeData.from(
      colorScheme: _lightColorScheme,
      textTheme: _textTheme(
        onSurface: DesignTokens.onSurface,
        onSurfaceVariant: DesignTokens.onSurfaceVariant,
      ),
    ).copyWith(
      // ===== 核心：所有背景色由 ColorScheme 驱动 =====
      scaffoldBackgroundColor: DesignTokens.surface,
      cardColor: DesignTokens.surfaceVariant,
      // ===== AppBar（亚克力效果需在 Widget 层实现）=====
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: DesignTokens.onSurface,
        elevation: 0,
        scrolledUnderElevation: 4,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: DesignTokens.onSurface,
        ),
      ),

      // ===== TabBar =====
      tabBarTheme: TabBarThemeData(
        dividerHeight: 0,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(width: 2),
          insets: EdgeInsets.only(bottom: 2),
        ),
        labelColor: DesignTokens.primary,
        unselectedLabelColor: DesignTokens.onSurfaceVariant,
        indicatorSize: TabBarIndicatorSize.label,
      ),

      // ===== Card =====
      cardTheme: CardThemeData(
        color: DesignTokens.surfaceVariant,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: .06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            DesignTokens.radius(RadiusSize.md),
          ),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(DesignTokens.primary),
          foregroundColor: WidgetStateProperty.all(DesignTokens.onPrimary),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                DesignTokens.radius(RadiusSize.sm),
              ),
            ),
          ),
          elevation: WidgetStateProperty.all(1.0),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DesignTokens.neutral100,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            DesignTokens.radius(RadiusSize.sm),
          ),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            DesignTokens.radius(RadiusSize.sm),
          ),
          borderSide: BorderSide(color: DesignTokens.neutral300, width: 1),
        ),
      ),
      listTileTheme: ListTileThemeData(
        minTileHeight: 48,
        contentPadding: EdgeInsets.symmetric(
          horizontal: DesignTokens.spacing(Spacing.md),
          vertical: DesignTokens.spacing(Spacing.xs),
        ),
        dense: true,
      ),
      iconTheme: const IconThemeData(size: 20, opacity: 0.8),
      chipTheme: ChipThemeData(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        labelStyle: TextStyle(fontSize: 12, color: DesignTokens.onSurface),
        backgroundColor: DesignTokens.neutral200,
        elevation: 0.5,
        shadowColor: Colors.black.withValues(alpha: .06),
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,

      extensions: [
        AppThemeExtension(
          primaryContainer: DesignTokens.primaryContainer,
          secondaryContainer: DesignTokens.secondary,
          surfaceVariant: DesignTokens.surfaceVariant,
          shadow: BoxShadow(
            blurRadius: 8,
            color: Colors.black.withValues(alpha: .06),
            offset: const Offset(0, 2),
          ),
        ),
      ],
    );
  }

  /// 构建深色主题
  static ThemeData _buildDarkTheme() {
    return ThemeData.from(
      colorScheme: _darkColorScheme,
      textTheme: _textTheme(
        onSurface: DesignTokens.onSurfaceDark,
        onSurfaceVariant: DesignTokens.onSurfaceVariantDark,
      ),
    ).copyWith(
      scaffoldBackgroundColor: DesignTokens.surfaceDark,
      cardColor: DesignTokens.surfaceVariantDark,

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: DesignTokens.onSurfaceDark,
        elevation: 0,
        scrolledUnderElevation: 4,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: DesignTokens.onSurfaceDark,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        dividerHeight: 0,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(width: 2),
          insets: EdgeInsets.only(bottom: 2),
        ),
        labelColor: DesignTokens.primary,
        unselectedLabelColor: DesignTokens.onSurfaceVariantDark,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      cardTheme: CardThemeData(
        color: DesignTokens.surfaceVariantDark,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: .2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            DesignTokens.radius(RadiusSize.md),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(DesignTokens.primary),
          foregroundColor: WidgetStateProperty.all(DesignTokens.onPrimary),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                DesignTokens.radius(RadiusSize.sm),
              ),
            ),
          ),
          elevation: WidgetStateProperty.all(1.0),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: DesignTokens.neutral800,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            DesignTokens.radius(RadiusSize.sm),
          ),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(
            DesignTokens.radius(RadiusSize.sm),
          ),
          borderSide: BorderSide(color: DesignTokens.neutral600, width: 1),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(
          horizontal: DesignTokens.spacing(Spacing.md),
          vertical: DesignTokens.spacing(Spacing.xs),
        ),
        dense: true,
        textColor: DesignTokens.onSurfaceDark,
        iconColor: DesignTokens.onSurfaceVariantDark,
      ),
      iconTheme: const IconThemeData(size: 20, opacity: 0.8),
      chipTheme: ChipThemeData(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        labelStyle: TextStyle(fontSize: 12, color: DesignTokens.onSurfaceDark),
        backgroundColor: DesignTokens.neutral700,
        elevation: 0.5,
        shadowColor: Colors.black.withValues(alpha: .15),
      ),
      visualDensity: VisualDensity.adaptivePlatformDensity,
      extensions: [
        AppThemeExtension(
          primaryContainer: DesignTokens.primaryContainer,
          secondaryContainer: DesignTokens.secondary,
          surfaceVariant: DesignTokens.surfaceVariant,
          shadow: BoxShadow(
            blurRadius: 8,
            color: Colors.black.withValues(alpha: .06),
            offset: const Offset(0, 2),
          ),
        ),
      ],
    );
  }

  // ===== 私有辅助方法 =====
  /// ColorScheme (浅色)
  static ColorScheme get _lightColorScheme => const ColorScheme.light(
    primary: DesignTokens.primary,
    onPrimary: DesignTokens.onPrimary,
    primaryContainer: DesignTokens.primaryContainer,
    onPrimaryContainer: DesignTokens.onPrimaryContainer,
    secondary: DesignTokens.secondary,
    onSecondary: DesignTokens.onPrimary,
    tertiary: DesignTokens.tertiary,
    error: DesignTokens.error,
    onError: Colors.white,
    surface: DesignTokens.surface,
    onSurface: DesignTokens.onSurface,
    surfaceContainerHighest: DesignTokens.surfaceVariant,
    onSurfaceVariant: DesignTokens.onSurfaceVariant,
    brightness: Brightness.light,
  );

  /// ColorScheme (深色)
  static ColorScheme get _darkColorScheme => const ColorScheme.dark(
    primary: DesignTokens.primary,
    onPrimary: DesignTokens.onPrimary,
    primaryContainer: DesignTokens.primaryContainer,
    onPrimaryContainer: DesignTokens.onPrimaryContainer,
    secondary: DesignTokens.secondary,
    onSecondary: DesignTokens.onPrimary,
    tertiary: DesignTokens.tertiary,
    error: DesignTokens.error,
    onError: Colors.white,
    surface: DesignTokens.surfaceDark,
    onSurface: DesignTokens.onSurfaceDark,
    surfaceContainerHighest: DesignTokens.surfaceVariantDark,
    onSurfaceVariant: DesignTokens.onSurfaceVariantDark,
    brightness: Brightness.dark,
  );

  /// 统一文本主题（避免重复）
  static TextTheme _textTheme({
    required Color onSurface,
    required Color onSurfaceVariant,
  }) {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      headlineLarge: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: onSurface,
      ),
      headlineMedium: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: onSurface,
      ),
      bodyLarge: TextStyle(fontSize: 14, color: onSurface, height: 1.4),
      bodyMedium: TextStyle(fontSize: 13, color: onSurfaceVariant, height: 1.3),
      labelLarge: TextStyle(
        fontSize: 11,
        color: onSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
