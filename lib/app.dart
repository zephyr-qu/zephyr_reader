import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
      final disposers = <void Function()>[];
      SharedPreferences.getInstance().then((prefs) {
        final autoTheme = AutoThemeService(prefs);
        disposers.add(
          effect(() {
            if (autoTheme.autoThemeEnabled.value) {
              themeManager.setThemeType(
                autoTheme.isDarkModeTime
                    ? AppThemeType.dark
                    : AppThemeType.light,
              );
            }
          }),
        );
      });
      return () {
        for (final d in disposers) {
          d();
        }
      };
    }, []);

    return Watch.builder(
      builder: (context) {
        return MaterialApp.router(
          routerConfig: router,
          debugShowCheckedModeBanner: false,
          theme: AppThemes.lightTheme,
          darkTheme: AppThemes.darkTheme,
          themeMode: themeManager.themeMode,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh'), Locale('en')],
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
