import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// 启动页。
///
/// 展示应用 Logo 和加载动画，初始化完成后自动跳转到首页。
class SplashPage extends HookWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(
      duration: const Duration(milliseconds: 800),
    );
    final fadeAnimation = useMemoized(
      () => CurvedAnimation(parent: controller, curve: Curves.easeIn),
      [controller],
    );
    controller.forward();

    useEffect(() {
      // 最小展示时长：保证动画（800ms）完整播完 + 留一点余量
      const minDisplay = Duration(milliseconds: 1200);
      final timer = Timer(minDisplay, () {
        if (context.mounted) context.go(RoutePaths.home);
      });
      return timer.cancel;
    }, []);

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                PhosphorIconsRegular.bookOpenText,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                'Zephyr',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.splashTagline,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
