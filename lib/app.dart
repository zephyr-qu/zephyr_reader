import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:zephyr_reader/core/local/preferences_service.dart';
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

    // 从 DI 获取 PreferencesService
    final prefs = useMemoized(() => getIt<PreferencesService>());

    final autoTheme = useMemoized(() => AutoThemeService(prefs));
    // 监听自动主题切换（根据时间切换亮/暗主题）
    // 安全说明：autoThemeEnabled 和 isDarkModeTime 变化时重运行效应，
    // 写入 themeType 不会触发回路——themeType 不被 autoTheme 读取，
    // 且 isDarkModeTime 基于系统时间（独立于 themeType）。
    useSignalEffect(() {
      if (autoTheme.autoThemeEnabled.value) {
        themeManager.themeType.value = autoTheme.isDarkModeTime
            ? AppThemeType.dark
            : AppThemeType.light;
      }
    });

    // 监听信号变化
    final Color? customPrimary = useSignalValue(
      themeManager.customPrimaryColor.signal,
    );
    final AppThemeType themeType = useSignalValue(themeManager.themeType.signal);
    final String? localeStr = useSignalValue(themeManager.locale.signal);

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
