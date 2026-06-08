import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// 首页错误状态视图。
///
/// 数据加载失败时显示错误信息和重试按钮。
class HomeErrorView extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onRetry;

  const HomeErrorView({
    super.key,
    required this.errorMessage,
    required this.onRetry,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(DesignTokens.spacing(Spacing.xl)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIconsRegular.warningCircle,
              size: 48,
              color: theme.colorScheme.error,
            ),
            SizedBox(height: DesignTokens.spacing(Spacing.md)),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            SizedBox(height: DesignTokens.spacing(Spacing.lg)),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(PhosphorIconsRegular.arrowClockwise, size: 18),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}
