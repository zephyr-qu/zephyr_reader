import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zephyr_reader/features/profile/page/user_agreement_page.dart';
import 'package:zephyr_reader/features/profile/page/privacy_policy_page.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';

// ─── Wind Swirl Painter ───────────────────────────────────────────────────────

class _WindSwirlPainter extends CustomPainter {
  final double phase;

  _WindSwirlPainter(this.phase);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 5; i++) {
      final offset = i * 0.4 + phase;
      final opacity = (0.06 + i * 0.04).clamp(0.0, 0.25);
      final width = 1.0 + i * 0.6;

      paint
        ..color = const Color(0xFF0288D1).withValues(alpha: opacity)
        ..strokeWidth = width;

      final path = Path();
      final startY = size.height * 0.3 + i * 30.0 + sin(offset) * 20;
      path.moveTo(-40, startY);

      for (double x = 0; x <= size.width + 40; x += 4) {
        final wave =
            sin(x * 0.006 + offset) * 18 + sin(x * 0.012 + offset * 1.3) * 8;
        path.lineTo(x, startY + wave);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WindSwirlPainter old) => old.phase != phase;
}

// ─── Floating Particles Painter ───────────────────────────────────────────────

class _ParticlePainter extends CustomPainter {
  final double phase;

  _ParticlePainter(this.phase);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 16; i++) {
      final seed = i * 137.0;
      final x = ((seed * 1.3) % size.width).toDouble();
      final yBase = (seed * 2.7) % size.height;
      final driftX = sin(phase * 0.5 + seed) * 30;
      final driftY = sin(phase * 0.7 + seed * 1.1) * 20;
      final px = (x + driftX).clamp(0.0, size.width);
      final py = ((yBase + driftY) % size.height).toDouble();
      final size_ = 1.5 + sin(phase + seed) * 1.0;

      canvas.drawCircle(
        Offset(px, py),
        size_.clamp(1.0, 3.0),
        Paint()..color = const Color(0xFFB3E5FC).withValues(alpha: 0.35),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => old.phase != phase;
}

// ─── Feature Card ─────────────────────────────────────────────────────────────

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final double delay;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - value)),
            child: Container(
              margin: EdgeInsets.only(
                left: DesignTokens.spacing(Spacing.md),
                right: DesignTokens.spacing(Spacing.md),
                bottom: DesignTokens.spacing(Spacing.sm),
              ),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: cs.primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Main Page ────────────────────────────────────────────────────────────────

class AboutPage extends HookWidget {
  const AboutPage({super.key});

  static const _features = [
    (PhosphorIconsRegular.cloudSlash, '纯离线使用', '核心功能 100% 离线可用，无后台无广告'),
    (PhosphorIconsRegular.gauge, '高性能解析', 'Rust 引擎驱动，大文件瞬间解析'),
    (PhosphorIconsRegular.translate, '双语排版', '中英文同等优先，优雅对照阅读'),
    (PhosphorIconsRegular.palette, '多主题支持', '亮色 / 深色 / 纯黑夜间模式'),
    (PhosphorIconsRegular.deviceMobile, '设备适配', '手机与平板双端自适应布局'),
    (PhosphorIconsRegular.arrowsClockwise, 'WebDAV 同步', '跨设备数据同步与安全备份'),
  ];

  static const _techStack = [
    ('Flutter', Color(0xFF027DFD)),
    ('Rust', Color(0xFFDEA584)),
    ('signals', Color(0xFF7B61FF)),
    ('go_router', Color(0xFF00BCD4)),
    ('frb', Color(0xFFE91E63)),
    ('SQLite', Color(0xFF003B57)),
  ];

  static const _links = [
    (PhosphorIconsRegular.downloadSimple, '检查更新', null, false),
    (PhosphorIconsRegular.fileText, '用户协议', null, false),
    (PhosphorIconsRegular.shieldCheck, '隐私政策', null, false),
    (PhosphorIconsRegular.scales, '开源许可证', null, false),
    (PhosphorIconsRegular.bug, '问题反馈', 'GitHub Issues', true),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final packageInfo = useFuture(
      useMemoized(() => PackageInfo.fromPlatform()),
    );
    final version = packageInfo.data?.version ?? '未知';
    final build = packageInfo.data?.buildNumber ?? '';

    final windCtrl = useAnimationController(
      duration: const Duration(seconds: 10),
    );
    useEffect(() {
      windCtrl.repeat();
      return null;
    }, []);

    final expandCtrl = useAnimationController(
      duration: const Duration(milliseconds: 1200),
    );
    useEffect(() {
      expandCtrl.forward();
      return null;
    }, []);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '关于',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: windCtrl,
            builder: (context, _) {
              return CustomPaint(
                size: Size.infinite,
                painter: _WindSwirlPainter(windCtrl.value * 2 * pi),
              );
            },
          ),
          AnimatedBuilder(
            animation: windCtrl,
            builder: (context, _) {
              return CustomPaint(
                size: Size.infinite,
                painter: _ParticlePainter(windCtrl.value * 2 * pi),
              );
            },
          ),
          ListView(
            padding: const EdgeInsets.only(top: kToolbarHeight + 8),
            physics: const BouncingScrollPhysics(),
            children: [
              // ── Header ─────────────────────────────────────────────────
              _HeaderSection(
                version: version,
                buildNumber: build,
                expandCtrl: expandCtrl,
              ),

              SizedBox(height: DesignTokens.spacing(Spacing.lg)),

              // ── Description ────────────────────────────────────────────
              _SectionCard(
                icon: PhosphorIconsRegular.bookOpenText,
                title: '应用介绍',
                delay: 0.05,
                child: Text(
                  'Zephyr Reader 是一款基于 Flutter + Rust 架构的离线双语小说阅读器。'
                  '纯本地设计，无后台、无广告、无数据收集，专注于中英双语阅读体验。',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                    color: cs.onSurface.withValues(alpha: 0.75),
                  ),
                ),
              ),

              SizedBox(height: DesignTokens.spacing(Spacing.md)),

              // ── Features ───────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.only(
                  left: DesignTokens.spacing(Spacing.md),
                  bottom: DesignTokens.spacing(Spacing.sm),
                ),
                child: Text(
                  '核心特性',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.5),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              SizedBox(height: DesignTokens.spacing(Spacing.xs)),
              ..._features.asMap().entries.map(
                (e) => _FeatureCard(
                  icon: e.value.$1,
                  title: e.value.$2,
                  subtitle: e.value.$3,
                  delay: 0.08 * e.key,
                ),
              ),

              SizedBox(height: DesignTokens.spacing(Spacing.lg)),

              // ── Tech Stack ─────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.only(
                  left: DesignTokens.spacing(Spacing.md),
                  bottom: DesignTokens.spacing(Spacing.sm),
                ),
                child: Text(
                  '技术栈',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.5),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: DesignTokens.spacing(Spacing.md),
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _techStack.map((t) {
                    return _TechChip(label: t.$1, color: t.$2);
                  }).toList(),
                ),
              ),

              SizedBox(height: DesignTokens.spacing(Spacing.lg)),

              // ── Links ──────────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.only(
                  left: DesignTokens.spacing(Spacing.md),
                  bottom: DesignTokens.spacing(Spacing.sm),
                ),
                child: Text(
                  '更多信息',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.5),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              _LinksSection(links: _links, version: version),

              SizedBox(height: DesignTokens.spacing(Spacing.xl)),

              // ── Footer ─────────────────────────────────────────────────
              _Footer(),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Header Section ───────────────────────────────────────────────────────────

class _HeaderSection extends StatelessWidget {
  final String version;
  final String buildNumber;
  final Animation<double> expandCtrl;

  const _HeaderSection({
    required this.version,
    required this.buildNumber,
    required this.expandCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 32 * (1 - value)),
            child: Column(
              children: [
                SizedBox(height: DesignTokens.spacing(Spacing.md)),
                // Icon with glow
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        cs.primaryContainer,
                        cs.primary.withValues(alpha: 0.3),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.2),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    PhosphorIconsBold.bookOpenText,
                    size: 40,
                    color: cs.primary,
                  ),
                ),
                SizedBox(height: DesignTokens.spacing(Spacing.md)),
                Text(
                  'Zephyr Reader',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: DesignTokens.spacing(Spacing.xs)),
                Text(
                  '如和风般轻盈的阅读体验',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.45),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                SizedBox(height: DesignTokens.spacing(Spacing.md)),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: cs.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        PhosphorIconsRegular.tag,
                        size: 14,
                        color: cs.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'v$version${buildNumber.isNotEmpty ? ' ($buildNumber)' : ''}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Section Card ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData? icon;
  final String title;
  final double delay;
  final Widget child;

  const _SectionCard({
    this.icon,
    required this.title,
    required this.delay,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: Container(
              margin: EdgeInsets.symmetric(
                horizontal: DesignTokens.spacing(Spacing.md),
              ),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: child,
            ),
          ),
        );
      },
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

  const _LinksSection({required this.links, required this.version});

  void _handleTap(BuildContext context, String title, String? subtitle) {
    switch (title) {
      case '检查更新':
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已是最新版本')));
      case '用户协议':
        Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const UserAgreementPage()),
        );
      case '隐私政策':
        Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const PrivacyPolicyPage()),
        );
      case '开源许可证':
        showLicensePage(
          context: context,
          applicationName: 'Zephyr Reader',
          applicationVersion: version,
          applicationLegalese: 'MIT License',
        );
      case '问题反馈':
        _launchUrl(
          context,
          'https://github.com/zephyr-reader/zephyr_reader/issues',
        );
    }
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开链接')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: DesignTokens.spacing(Spacing.md),
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: links.asMap().entries.map((entry) {
          final i = entry.key;
          final (icon, title, subtitle, isExternal) = entry.value;
          return Column(
            children: [
              if (i > 0)
                Divider(
                  height: 1,
                  indent: 56,
                  color: cs.outlineVariant.withValues(alpha: 0.3),
                ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: cs.primary),
                ),
                title: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: subtitle != null
                    ? Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.45),
                        ),
                      )
                    : null,
                trailing: Icon(
                  isExternal
                      ? PhosphorIconsRegular.arrowSquareOut
                      : PhosphorIconsRegular.caretRight,
                  size: 18,
                  color: cs.onSurface.withValues(alpha: 0.35),
                ),
                onTap: () => _handleTap(context, title, subtitle),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─── Footer ───────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.all(DesignTokens.spacing(Spacing.xl)),
      child: Column(
        children: [
          Icon(
            PhosphorIconsRegular.wind,
            size: 20,
            color: cs.onSurface.withValues(alpha: 0.15),
          ),
          SizedBox(height: DesignTokens.spacing(Spacing.sm)),
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
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
