import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/features/profile/page/about/feature_card.dart';
import 'package:zephyr_reader/features/profile/page/widgets/settings_app_bar.dart';
import 'package:zephyr_reader/features/profile/page/about/links_section.dart';
import 'package:zephyr_reader/features/profile/page/about/tech_chip.dart';
import 'package:zephyr_reader/features/profile/page/about/about_header.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

// ─── Main Page ────────────────────────────────────────────────────────────────

/// 关于页面。
///
/// 展示应用品牌故事、版本、功能特性、技术栈和相关链接。
/// 采用编辑式布局，强调品牌温度与工艺感，替代旧版设置卡片风格。
class AboutPage extends HookWidget {
  const AboutPage({super.key});

  List<(IconData, String, String)> _buildFeatures(AppLocalizations l10n) => [
    (
      PhosphorIconsRegular.cloudSlash,
      l10n.aboutFeatureOffline,
      l10n.aboutFeatureOfflineDesc,
    ),
    (
      PhosphorIconsRegular.gauge,
      l10n.aboutFeaturePerformance,
      l10n.aboutFeaturePerformanceDesc,
    ),
    (
      PhosphorIconsRegular.palette,
      l10n.aboutFeatureThemes,
      l10n.aboutFeatureThemesDesc,
    ),
    (
      PhosphorIconsRegular.deviceMobile,
      l10n.aboutFeatureAdaptive,
      l10n.aboutFeatureAdaptiveDesc,
    ),
  ];

  static const _techStack = [
    ('Flutter', Color(0xFF027DFD)),
    ('Rust', Color(0xFFDEA584)),
    ('signals', Color(0xFF7B61FF)),
    ('go_router', Color(0xFF00BCD4)),
    ('frb', Color(0xFFE91E63)),
    ('SQLite', Color(0xFF003B57)),
  ];

  List<(IconData, String, String?, bool)> _buildLinks(
    AppLocalizations l10n,
  ) => [
    (PhosphorIconsRegular.downloadSimple, l10n.aboutCheckUpdate, null, false),
    (PhosphorIconsRegular.fileText, l10n.aboutUserAgreement, null, false),
    (PhosphorIconsRegular.shieldCheck, l10n.aboutPrivacyPolicy, null, false),
    (PhosphorIconsRegular.scales, l10n.aboutOpenSourceLicense, null, false),
    (PhosphorIconsRegular.bug, l10n.aboutFeedback, 'GitHub Issues', true),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final packageInfo = useFuture(
      useMemoized(() => PackageInfo.fromPlatform()),
    );
    final version = packageInfo.data?.version ?? l10n.unknownVersion;
    final build = packageInfo.data?.buildNumber ?? '';

    return Scaffold(
      appBar: SettingsAppBar(title: l10n.aboutTitle),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 48),
        children: [
          const SizedBox(height: 8),

          // ── Header ────────────────────────────────────────────────
          AboutHeader(version: version, buildNumber: build, l10n: l10n),

          const SizedBox(height: 28),

          // ── Warm decorative divider ───────────────────────────────
          _warmDivider(),

          const SizedBox(height: 24),

          // ── Brand Manifesto ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              l10n.aboutDescription,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.7,
                color: cs.onSurface.withValues(alpha: 0.75),
                letterSpacing: 0.2,
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── Features Section ──────────────────────────────────────
          _sectionHeader(context, l10n.aboutSectionFeatures),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = (constraints.maxWidth - 8) / 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _buildFeatures(l10n)
                      .map(
                        (e) => SizedBox(
                          width: cardWidth,
                          child: FeatureCard(
                            icon: e.$1,
                            title: e.$2,
                            subtitle: e.$3,
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // ── Warm decorative divider ───────────────────────────────
          _warmDivider(),

          const SizedBox(height: 24),

          // ── Tech Stack ────────────────────────────────────────────
          _sectionHeader(context, l10n.aboutSectionTechStack),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _techStackCard(context),
          ),

          const SizedBox(height: 24),

          // ── Links ─────────────────────────────────────────────────
          _sectionHeader(context, l10n.aboutSectionLinks),
          const SizedBox(height: 12),
          LinksSection(links: _buildLinks(l10n), version: version),

          const SizedBox(height: 40),

          // ── Footer ────────────────────────────────────────────────
          _buildFooter(cs),
        ],
      ),
    );
  }

  // ─── Section Header ───────────────────────────────────────────────────────

  /// 编辑风格的分区标题，带暖色竖线装饰，替代旧版 [SectionLabel]。
  Widget _sectionHeader(BuildContext context, String label) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 24),
      child: Row(
        children: [
          // Warm accent vertical accent bar
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: DesignTokens.primary,
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.55),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tech Stack Card ─────────────────────────────────────────────────────

  /// 技术栈卡片 — 用品牌暖色边框替代旧版 [SettingsCard]。
  Widget _techStackCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: DesignTokens.warmAccent.withValues(alpha: 0.12),
          width: 0.5,
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _techStack.map((t) {
          return TechChip(label: t.$1, color: t.$2);
        }).toList(),
      ),
    );
  }

  // ─── Warm Decorative Divider ─────────────────────────────────────────────

  /// 编辑风格的装饰分割线 — 短粗暖色圆条 + 细线，书写段落间的喘息空间。
  Widget _warmDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 2,
            decoration: BoxDecoration(
              color: DesignTokens.warmAccent.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 0.5,
              color: DesignTokens.warmAccent.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Footer ─────────────────────────────────────────────────────────────

  /// 品牌页脚 — 暖色分割线 + 版本声明 + 技术致敬。
  Widget _buildFooter(ColorScheme cs) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            height: 0.5,
            color: DesignTokens.warmAccent.withValues(alpha: 0.12),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '© 2026 Zephyr Reader',
          style: TextStyle(
            fontSize: 12,
            color: DesignTokens.warmAccent.withValues(alpha: 0.4),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Made with',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.25),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              PhosphorIconsFill.heart,
              size: 11,
              color: DesignTokens.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 4),
            Text(
              '· Flutter · Rust',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.25),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
