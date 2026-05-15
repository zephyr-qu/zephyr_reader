import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zephyr_reader/core/theme/app_theme.dart';
import 'package:zephyr_reader/core/theme/auto_theme_service.dart';
import 'package:zephyr_reader/core/theme/theme_manager.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'core/routing/app_router.dart';

class MyApp extends HookWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeManager = ThemeManager.instance;

    useEffect(() {
      themeManager.init();
      return null;
    }, []);

    useEffect(() {
      SharedPreferences.getInstance().then((prefs) {
        final autoTheme = AutoThemeService(prefs);
        effect(() {
          if (autoTheme.autoThemeEnabled.value) {
            themeManager.setThemeType(
              autoTheme.isDarkModeTime ? AppThemeType.dark : AppThemeType.light,
            );
          }
        });
      });
      return null;
    }, []);

    return Watch.builder(
      builder: (context) {
        return MaterialApp.router(
          routerConfig: router,
          debugShowCheckedModeBanner: false,
          theme: AppThemes.lightTheme,
          darkTheme: AppThemes.darkTheme,
          themeMode: themeManager.themeMode,
        );
      },
    );
  }
}
