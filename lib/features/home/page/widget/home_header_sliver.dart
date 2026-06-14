import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// 首页问候语头部。
///
/// 根据时间段显示对应的问候语。
class HomeHeaderSliver extends StatelessWidget {
  final String greeting;

  const HomeHeaderSliver({super.key, required this.greeting});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        Spacing.md.value,
        Spacing.lg.value,
        Spacing.md.value,
        0,
      ),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              greeting,
            style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 2),
            Text(
              l10n.continueReading,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
