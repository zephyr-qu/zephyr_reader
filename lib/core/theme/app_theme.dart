import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/theme/theme_extension.dart';


// ==================== 排版常量（7 档，无 color，const 零开销） ====================

const _hero = TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5);
const _screenTitle = TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.3);
const _sectionTitle = TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.2);
const _itemTitle = TextStyle(fontSize: 17, fontWeight: FontWeight.w500, letterSpacing: -0.2);
const _body = TextStyle(fontSize: 14, fontWeight: FontWeight.w400);
const _label = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.2);
const _caption = TextStyle(fontSize: 11, fontWeight: FontWeight.w400);

/// 应用主题工厂
///
/// 构建基于 Material 3 的亮色/深色 [ThemeData]，支持自定义主色。
/// 提供统一的 AppBar、卡片、按钮、输入框等组件主题配置，
/// 并注入自定义 [AppThemeExtension] 和 [ReaderThemeExtension]。
class AppThemes {
  AppThemes._();

  // ===== 排版 scale（与 file-private _hero 等共享同一 const，零开销）=====

  /// 大 Banner、首页推荐标题（28/w700）
  static const TextStyle hero = _hero;

  /// 页面大标题（24/w700）
  static const TextStyle screenTitle = _screenTitle;

  /// 区域/板块标题（20/w600）
  static const TextStyle sectionTitle = _sectionTitle;

  /// 列表项标题、卡片标题（17/w500）
  static const TextStyle itemTitle = _itemTitle;

  /// 正文段落、列表副文本（14/w400）
  static const TextStyle body = _body;

  /// 按钮、标签、Tab、辅助文字（12/w500）
  static const TextStyle label = _label;

  /// 极小说明、时间戳、脚注（11/w400）
  static const TextStyle caption = _caption;

  /// 界面 chrome 默认字族。
  /// Noto Sans SC — 多数 Android 预装，iOS 无则 fallback 系统字体。
  static const String fontFamily = 'Noto Sans SC';

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
    final onPrimary = _contrastingTextColor(primary);
    final isDark = brightness == Brightness.dark;

    final Color scaffoldBg = isDark ? _bgDark : _bgLight;
    final Color textPri = isDark ? _textPriDark : _textPriLight;
    final Color textSec = isDark ? _textSecDark : _textSecLight;
    final Color surf = isDark ? _surfaceDark : _surfaceLight;
    final Color div = isDark ? _dividerDark : _dividerLight;

    return ThemeData(
      fontFamily: fontFamily,
      useMaterial3: true,
      brightness: brightness,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: (brightness == Brightness.dark
              ? ColorScheme.dark
              : ColorScheme.light)(
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
          elevation: WidgetStateProperty.all(0),
          textStyle: WidgetStateProperty.all(
            _body.copyWith(fontWeight: FontWeight.w500),
          ),
          ),
        ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RadiusSize.md.value),
          )),
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
        contentPadding: EdgeInsets.symmetric(
          horizontal: Spacing.md.value,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusSize.md.value),
          borderSide: BorderSide(color: div, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusSize.md.value),
          borderSide: BorderSide(color: div, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusSize.md.value),
          borderSide: BorderSide(color: primary, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RadiusSize.md.value),
          borderSide: const BorderSide(color: DesignTokens.error, width: 0.5),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RadiusSize.md.value),
          side: BorderSide(color: div, width: 0.5),
        ),
        elevation: 0,
        color: surf,
        surfaceTintColor: Colors.transparent,
      ),

      listTileTheme: ListTileThemeData(
        minTileHeight: 44,
        contentPadding: EdgeInsets.symmetric(
          horizontal: Spacing.md.value,
          vertical: 2,
        ),
        dense: true,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textPri,
        ),
        subtitleTextStyle: _body.copyWith(color: textSec),
        iconColor: textSec,
      ),

      iconTheme: IconThemeData(size: IconSize.nav, color: textSec),
      chipTheme: ChipThemeData(
        padding: EdgeInsets.symmetric(
          horizontal: Spacing.sm.value,
          vertical: Spacing.xs.value,
        ),
        labelStyle: _label.copyWith(color: textPri),
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
            return _label.copyWith(color: primary);
          }
          return _label.copyWith(color: textSec);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(size: IconSize.nav, color: primary);
          }
          return IconThemeData(size: IconSize.nav, color: textSec);
        }),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        selectedIconTheme: IconThemeData(size: IconSize.nav, color: primary),
        unselectedIconTheme: IconThemeData(size: IconSize.nav, color: textSec),
        selectedLabelTextStyle: _label.copyWith(color: primary),
        unselectedLabelTextStyle: _label.copyWith(color: textSec),
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
      ],
    );
  }

  /// 构建应用文本主题。
  ///
  /// 覆盖 7 个 M3 slot，其余保持 M3 默认。
  static TextTheme _textTheme({
    required Color onSurface,
    required Color onSurfaceVariant,
  }) {
    return TextTheme(
      headlineMedium: _hero.copyWith(color: onSurface),
      headlineLarge: _screenTitle.copyWith(color: onSurface),
      headlineSmall: _sectionTitle.copyWith(color: onSurface),
      titleLarge: _itemTitle.copyWith(color: onSurface),
      bodyLarge: _body.copyWith(color: onSurface),
      labelLarge: _label.copyWith(color: onSurfaceVariant),
      labelSmall: _caption.copyWith(color: onSurfaceVariant),
    );
  }
}

/// 根据背景色亮度返回白色或深色前景文字颜色。
Color _contrastingTextColor(Color bg) {
  final luminance = 0.2126 * bg.r + 0.7152 * bg.g + 0.0722 * bg.b;
  return luminance > 0.5 ? const Color(0xFF1A1C1E) : Colors.white;
}
