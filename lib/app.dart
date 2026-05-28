import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr_reader/core/theme/app_theme.dart';
import 'package:zephyr_reader/core/theme/auto_theme_service.dart';
import 'package:zephyr_reader/core/theme/theme_manager.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'core/routing/app_router.dart';
import 'l10n/app_localizations.dart';

class MyApp extends HookWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeManager = ThemeManager.instance;

    // 使用 useEffect 并传入空数组 [] 进行一次性初始化
    useEffect(() {
      themeManager.init();
      return null;
    }, []);

    // 使用 useFuture 处理异步的 SharedPreferences 初始化
    final prefsFuture = useMemoized(() => SharedPreferences.getInstance(), []);
    final prefs = useFuture(prefsFuture);

    // 使用 useSignalEffect 监听自动主题切换逻辑
    if (prefs.hasData) {
      final autoTheme = useMemoized(() => AutoThemeService(prefs.data!), [
        prefs.data,
      ]);

      useSignalEffect(() {
        if (autoTheme.autoThemeEnabled.value) {
          themeManager.setThemeType(
            autoTheme.isDarkModeTime ? AppThemeType.dark : AppThemeType.light,
          );
        }
      });
    }

    // Watch.builder 仅订阅 builder 内访问的信号（themeMode、appLocale），
    // 不会因其他信号变化而重建 MaterialApp。
    return Watch.builder(
      builder: (context) {
        return MaterialApp.router(
          routerConfig: router,
          debugShowCheckedModeBanner: false,
          theme: AppThemes.lightTheme,
          darkTheme: AppThemes.darkTheme,
          themeMode: themeManager.themeMode,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: themeManager.appLocale,
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
      },
    );
  }
}
