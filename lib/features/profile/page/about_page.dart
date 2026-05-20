/// 关于页面
///
/// 显示应用信息、版本、许可证等
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zephyr_reader/features/profile/page/user_agreement_page.dart';
import 'package:zephyr_reader/features/profile/page/privacy_policy_page.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';

/// 关于页面
class AboutPage extends HookWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final packageInfo = useFuture(
      useMemoized(() => PackageInfo.fromPlatform()),
    );

    final version = packageInfo.data?.version ?? '未知';
    final buildNumber = packageInfo.data?.buildNumber ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        children: [
          // 应用图标和名称
          Padding(
            padding: EdgeInsets.all(DesignTokens.spacing(Spacing.xl)),
            child: Column(
              children: [
                Icon(
                  PhosphorIconsRegular.bookOpenText,
                  size: 80,
                  color: theme.colorScheme.primary,
                ),
                SizedBox(height: DesignTokens.spacing(Spacing.md)),
                Text(
                  'Zephyr Reader',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: DesignTokens.spacing(Spacing.sm)),
                Text(
                  '如和风般轻盈的阅读体验',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                SizedBox(height: DesignTokens.spacing(Spacing.md)),
                Chip(
                  label: Text('v$version ($buildNumber)'),
                  avatar: const Icon(PhosphorIconsRegular.info, size: 16),
                ),
              ],
            ),
          ),

          // 应用介绍
          _buildSection(
            context,
            title: '应用介绍',
            children: [
              Padding(
                padding: EdgeInsets.all(DesignTokens.spacing(Spacing.md)),
                child: Text(
                  'Zephyr Reader 是一款基于 Flutter + Rust 架构开发的安卓端双语离线小说阅读器。'
                  '项目采用纯本地设计，无后台、无广告、无数据收集，专注于中文、英文双语小说的阅读体验。',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ],
          ),

          // 核心特性
          _buildSection(
            context,
            title: '核心特性',
            children: [
              _buildFeatureItem(
                context,
                icon: PhosphorIconsRegular.cloudSlash,
                title: '纯离线使用',
                subtitle: '核心功能 100% 离线可用',
              ),
              const Divider(height: 1),
              _buildFeatureItem(
                context,
                icon: PhosphorIconsRegular.gauge,
                title: '高性能解析',
                subtitle: 'Rust 实现文本解析，大文件加载流畅',
              ),
              const Divider(height: 1),
              _buildFeatureItem(
                context,
                icon: PhosphorIconsRegular.translate,
                title: '双语排版',
                subtitle: '中文、英文同等优先的排版优化',
              ),
              const Divider(height: 1),
              _buildFeatureItem(
                context,
                icon: PhosphorIconsRegular.palette,
                title: '多主题支持',
                subtitle: '亮色/深色/纯黑夜间主题',
              ),
              const Divider(height: 1),
              _buildFeatureItem(
                context,
                icon: PhosphorIconsRegular.deviceMobile,
                title: '设备适配',
                subtitle: '手机、平板双端自适应',
              ),
              const Divider(height: 1),
              _buildFeatureItem(
                context,
                icon: PhosphorIconsRegular.arrowsClockwise,
                title: 'WebDAV 同步',
                subtitle: '支持跨设备数据同步与备份',
              ),
            ],
          ),

          // 技术栈
          _buildSection(
            context,
            title: '技术栈',
            children: [
              Padding(
                padding: EdgeInsets.all(DesignTokens.spacing(Spacing.md)),
                child: Wrap(
                  spacing: DesignTokens.spacing(Spacing.sm),
                  runSpacing: DesignTokens.spacing(Spacing.sm),
                  children: const [
                    Chip(label: Text('Flutter 3.22')),
                    Chip(label: Text('Rust 1.75')),
                    Chip(label: Text('Drift')),
                    Chip(label: Text('signals_flutter')),
                    Chip(label: Text('go_router')),
                    Chip(label: Text('flutter_rust_bridge')),
                  ],
                ),
              ),
            ],
          ),

          // 更多信息
          _buildSection(
            context,
            title: '更多信息',
            children: [
              ListTile(
                title: const Text('检查更新'),
                leading: const Icon(PhosphorIconsRegular.downloadSimple),
                trailing: const Icon(PhosphorIconsRegular.caretRight),
                onTap: () {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('已是最新版本')));
                },
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('用户协议'),
                leading: const Icon(PhosphorIconsRegular.fileText),
                trailing: const Icon(PhosphorIconsRegular.caretRight),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UserAgreementPage(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('隐私政策'),
                leading: const Icon(PhosphorIconsRegular.shieldCheck),
                trailing: const Icon(PhosphorIconsRegular.caretRight),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PrivacyPolicyPage(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('开源许可证'),
                leading: const Icon(PhosphorIconsRegular.scales),
                trailing: const Icon(PhosphorIconsRegular.caretRight),
                onTap: () {
                  showLicensePage(
                    context: context,
                    applicationName: 'Zephyr Reader',
                    applicationVersion: version,
                    applicationLegalese: 'MIT License',
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('问题反馈'),
                subtitle: const Text('GitHub Issues'),
                leading: const Icon(PhosphorIconsRegular.bug),
                trailing: const Icon(PhosphorIconsRegular.arrowSquareOut),
                onTap: () async {
                  final uri = Uri.parse(
                    'https://github.com/zephyr-reader/zephyr_reader/issues',
                  );
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('无法打开链接')));
                    }
                  }
                },
              ),
            ],
          ),

          SizedBox(height: DesignTokens.spacing(Spacing.xl)),

          // 版权信息
          Center(
            child: Padding(
              padding: EdgeInsets.all(DesignTokens.spacing(Spacing.md)),
              child: Text(
                '© 2026 Zephyr Reader\nMade with ❤️ by Flutter + Rust',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            DesignTokens.spacing(Spacing.md),
            DesignTokens.spacing(Spacing.md),
            DesignTokens.spacing(Spacing.md),
            DesignTokens.spacing(Spacing.sm),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Column(children: children),
      ],
    );
  }

  Widget _buildFeatureItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.all(DesignTokens.spacing(Spacing.md)),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 28),
          SizedBox(width: DesignTokens.spacing(Spacing.md)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
