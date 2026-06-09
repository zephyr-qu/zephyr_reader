import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/core/theme/app_theme.dart';
import 'package:zephyr_reader/core/theme/auto_theme_service.dart';
import 'package:zephyr_reader/core/theme/theme_manager.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'core/routing/app_router.dart';
import 'l10n/app_localizations.dart';

/// Zephyr Reader 应用根组件
class ZephyrReaderApp extends HookWidget {
  const ZephyrReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeManager = ThemeManager.instance;

    // 使用 useEffect 并传入空数组 [] 进行一次性初始化
    useEffect(() {
      themeManager.init();
      return null;
    }, []);

    // 从 DI 获取 SharedPreferences 单例
    final prefs = useMemoized(() => getIt<SharedPreferences>());

    // 使用 useSignalEffect 监听自动主题切换逻辑
    final autoTheme = useMemoized(() => AutoThemeService(prefs));
    useSignalEffect(() {
      if (autoTheme.autoThemeEnabled.value) {
        themeManager.themeType.value = autoTheme.isDarkModeTime
            ? AppThemeType.dark
            : AppThemeType.light;
      }
    });

    // 监听信号变化
    final customPrimary = useSignalValue<Color?, Signal<Color?>>(
      themeManager.customPrimaryColor,
    );
    final themeType = useSignalValue<AppThemeType, Signal<AppThemeType>>(
      themeManager.themeType,
    );
    final localeStr = useSignalValue<String?, Signal<String?>>(
      themeManager.locale,
    );

    // 缓存 ThemeData，仅在 customPrimary 变化时重建
    final theme = useMemoized(
      () =>
          AppThemes.buildTheme(Brightness.light, customPrimary: customPrimary),
      [customPrimary],
    );
    final darkTheme = useMemoized(
      () => AppThemes.buildTheme(Brightness.dark, customPrimary: customPrimary),
      [customPrimary],
    );

    // 导出 Material 值
    final themeMode = useMemoized(
      () => switch (themeType) {
        AppThemeType.light => ThemeMode.light,
        AppThemeType.dark => ThemeMode.dark,
        AppThemeType.system => ThemeMode.system,
      },
      [themeType],
    );

    final appLocale = useMemoized(
      () => localeStr != null ? Locale(localeStr) : null,
      [localeStr],
    );

    return MaterialApp.router(
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: appLocale,
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale == null) return null;
        for (final supported in supportedLocales) {
          if (supported.languageCode == locale.languageCode) {
            return supported;
          }
        }
        return const Locale('zh');
      },
    );
  }
}
