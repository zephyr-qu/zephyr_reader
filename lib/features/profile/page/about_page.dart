import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_card.dart';
import 'package:zephyr_reader/features/profile/page/user_agreement_page.dart';
import 'package:zephyr_reader/features/profile/page/privacy_policy_page.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

// ─── Feature Card ─────────────────────────────────────────────────────────────

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.25),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: cs.primary, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Main Page ────────────────────────────────────────────────────────────────

class AboutPage extends HookWidget {
  const AboutPage({super.key});

  List<(IconData, String, String)> _buildFeatures(AppLocalizations l10n) => [
    (PhosphorIconsRegular.cloudSlash, l10n.aboutFeatureOffline, l10n.aboutFeatureOfflineDesc),
    (PhosphorIconsRegular.gauge, l10n.aboutFeaturePerformance, l10n.aboutFeaturePerformanceDesc),
    (PhosphorIconsRegular.translate, l10n.aboutFeatureBilingual, l10n.aboutFeatureBilingualDesc),
    (PhosphorIconsRegular.palette, l10n.aboutFeatureThemes, l10n.aboutFeatureThemesDesc),
    (PhosphorIconsRegular.deviceMobile, l10n.aboutFeatureAdaptive, l10n.aboutFeatureAdaptiveDesc),
    (PhosphorIconsRegular.arrowsClockwise, l10n.aboutFeatureSync, l10n.aboutFeatureSyncDesc),
  ];

  static const _techStack = [
    ('Flutter', Color(0xFF027DFD)),
    ('Rust', Color(0xFFDEA584)),
    ('signals', Color(0xFF7B61FF)),
    ('go_router', Color(0xFF00BCD4)),
    ('frb', Color(0xFFE91E63)),
    ('SQLite', Color(0xFF003B57)),
  ];

  List<(IconData, String, String?, bool)> _buildLinks(AppLocalizations l10n) => [
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
      appBar: AppBar(
        title: Text(
          l10n.aboutTitle,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 40),
        children: [
          const SizedBox(height: 8),

          // ── Header ─────────────────────────────────────────────────
          _buildHeader(cs, theme, version, build, l10n),

          const SizedBox(height: 28),

          // ── Description ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              l10n.aboutDescription,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.6,
                color: cs.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ── Features ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 24, bottom: 10),
            child: Text(
              l10n.aboutSectionFeatures,
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.outline,
                letterSpacing: 0.4,
              ),
            ),
          ),
          ..._buildFeatures(l10n).map(
            (e) => _FeatureCard(icon: e.$1, title: e.$2, subtitle: e.$3),
          ),

          const SizedBox(height: 24),

          // ── Tech Stack ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 24, bottom: 10),
            child: Text(
              l10n.aboutSectionTechStack,
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.outline,
                letterSpacing: 0.4,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SettingsCard(
              colorScheme: cs,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _techStack.map((t) {
                      return _TechChip(label: t.$1, color: t.$2);
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Links ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(left: 24, bottom: 10),
            child: Text(
              l10n.aboutSectionLinks,
              style: theme.textTheme.labelLarge?.copyWith(
                color: cs.outline,
                letterSpacing: 0.4,
              ),
            ),
          ),
          _LinksSection(links: _buildLinks(l10n), version: version, l10n: l10n),

          const SizedBox(height: 32),

          // ── Footer ─────────────────────────────────────────────────
          _buildFooter(cs),
        ],
      ),
    );
  }

  Widget _buildHeader(
    ColorScheme cs,
    ThemeData theme,
    String version,
    String build,
    AppLocalizations l10n,
  ) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(
            PhosphorIconsBold.bookOpenText,
            size: 34,
            color: cs.primary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Zephyr Reader',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.aboutTagline,
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.45),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'v$version${build.isNotEmpty ? ' ($build)' : ''}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(ColorScheme cs) {
    return Column(
      children: [
        Text(
          '© 2026 Zephyr Reader',
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurface.withValues(alpha: 0.3),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Made with Flutter · Rust · ❤',
          style: TextStyle(
            fontSize: 11,
            color: cs.onSurface.withValues(alpha: 0.2),
          ),
        ),
      ],
    );
  }
}

// ─── Tech Chip ────────────────────────────────────────────────────────────────

class _TechChip extends StatelessWidget {
  final String label;
  final Color color;

  const _TechChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bg = brightness == Brightness.light
        ? color.withValues(alpha: 0.1)
        : color.withValues(alpha: 0.18);
    final fg = brightness == Brightness.light
        ? color
        : color.withValues(alpha: 0.9);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─── Links Section ────────────────────────────────────────────────────────────

class _LinksSection extends StatelessWidget {
  final List<(IconData, String, String?, bool)> links;
  final String version;
  final AppLocalizations l10n;

  const _LinksSection({required this.links, required this.version, required this.l10n});

  void _handleTap(BuildContext context, String title) {
    if (title == l10n.aboutCheckUpdate) {
      ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.aboutLatestVersion)));
    } else if (title == l10n.aboutUserAgreement) {
      Navigator.push(context,
        MaterialPageRoute<void>(builder: (_) => const UserAgreementPage()));
    } else if (title == l10n.aboutPrivacyPolicy) {
      Navigator.push(context,
        MaterialPageRoute<void>(builder: (_) => const PrivacyPolicyPage()));
    } else if (title == l10n.aboutOpenSourceLicense) {
      showLicensePage(
        context: context,
        applicationName: 'Zephyr Reader',
        applicationVersion: version,
        applicationLegalese: 'MIT License',
      );
    } else if (title == l10n.aboutFeedback) {
      _launchUrl(context, 'https://github.com/zephyr-reader/zephyr_reader/issues');
    }
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.aboutCannotOpenLink)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.25),
            width: 0.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: links.asMap().entries.map((entry) {
            final i = entry.key;
            final (icon, title, subtitle, isExternal) = entry.value;
            final isLast = i == links.length - 1;
            return Column(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _handleTap(context, title),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        border: isLast
                            ? null
                            : Border(
                                bottom: BorderSide(
                                  color: cs.outlineVariant.withValues(
                                    alpha: 0.15,
                                  ),
                                  width: 0.5,
                                ),
                              ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: cs.primaryContainer.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(icon, size: 17, color: cs.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: cs.onSurface,
                                  ),
                                ),
                                if (subtitle != null)
                                  Text(
                                    subtitle,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Icon(
                            isExternal
                                ? PhosphorIconsRegular.arrowSquareOut
                                : PhosphorIconsRegular.caretRight,
                            size: 16,
                            color: cs.onSurface.withValues(alpha: 0.3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
