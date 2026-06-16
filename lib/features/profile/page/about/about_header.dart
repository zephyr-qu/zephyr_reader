import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// 应用标志头部。
///
/// 在关于页面顶部展示应用名称、图标、标语和版本号，
/// 使用品牌暖色渐变背景增强视觉层次。
class AboutHeader extends StatelessWidget {
  final String version;
  final String buildNumber;
  final AppLocalizations l10n;

  const AboutHeader({
    super.key,
    required this.version,
    required this.buildNumber,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final warmAccent = DesignTokens.warmAccent;

    return Column(
      children: [
        const SizedBox(height: 8),
        // Warm gradient decorative icon container
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                DesignTokens.primary.withValues(alpha: 0.15),
                warmAccent.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Center(
            child: Icon(
              PhosphorIconsBold.bookOpenText,
              size: 40,
              color: DesignTokens.primary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Zephyr Reader',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.8,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.aboutTagline,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: warmAccent,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 14),
        // Version badge with warm accents
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: DesignTokens.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: DesignTokens.primary.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
          child: Text(
            'v$version${buildNumber.isNotEmpty ? ' ($buildNumber)' : ''}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: DesignTokens.primary,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }
}
