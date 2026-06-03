import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/section_label.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_card.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_navigation_tile.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_toggle_tile.dart';
import 'package:zephyr_reader/core/theme/menu_colors.dart';
import 'package:zephyr_reader/core/theme/theme_manager.dart';
import 'package:zephyr_reader/features/profile/page/other_settings/other_settings_view_model.dart';
import 'package:zephyr_reader/features/profile/page/privacy_policy_page.dart';
import 'package:zephyr_reader/features/profile/page/user_agreement_page.dart';

class OtherSettingsPage extends HookWidget {
  late final OtherSettingsViewModel vm = getIt<OtherSettingsViewModel>();

  OtherSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    useEffect(() {
      vm.initialize();
      return null;
    }, []);

    final cs = Theme.of(context).colorScheme;

    final String localeLabel = useSignalValue(vm.localeLabel);
    final String appVersion = useSignalValue(vm.appVersion);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '其他设置',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          _buildBehaviorSection(context, cs, localeLabel),
          const SizedBox(height: 24),
          _buildExperimentalSection(context, cs),
          const SizedBox(height: 24),
          _buildLegalSection(context, cs),
          const SizedBox(height: 24),
          _buildDangerSection(context, cs),
          const SizedBox(height: 24),
          _buildVersionFooter(context, cs, appVersion),
        ],
      ),
    );
  }

  Widget _buildBehaviorSection(
    BuildContext context,
    ColorScheme cs,
    String localeLabel,
  ) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(label: '应用行为', colorScheme: cs),
            SettingsCard(
              colorScheme: cs,
              showDividers: true,
              children: [
                SettingsNavigationTile(
                  icon: PhosphorIconsRegular.translate,
                  iconColor: MenuItemSemantic.info.iconColor(
                    Theme.of(context).brightness,
                  ),
                  iconBackground: MenuItemSemantic.info.iconBackground(
                    Theme.of(context).brightness,
                  ),
                  title: '界面语言',
                  subtitle: '简体中文 / English',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        localeLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        PhosphorIconsRegular.caretRight,
                        size: 14,
                        color: cs.onSurface.withValues(alpha: 0.3),
                      ),
                    ],
                  ),
                  onTap: () => _showLanguageSheet(context, cs),
                ),
                SettingsToggleTile(
                  icon: PhosphorIconsRegular.bell,
                  iconColor: MenuItemSemantic.warning.iconColor(
                    Theme.of(context).brightness,
                  ),
                  iconBackground: MenuItemSemantic.warning.iconBackground(
                    Theme.of(context).brightness,
                  ),
                  title: '通知与提醒',
                  subtitle: '阅读目标提醒、同步完成通知',
                  value: vm.notificationsEnabled.value,
                  onChanged: (v) => vm.notificationsEnabled.value = v,
                ),
                SettingsToggleTile(
                  icon: PhosphorIconsRegular.arrowArcRight,
                  iconColor: MenuItemSemantic.success.iconColor(
                    Theme.of(context).brightness,
                  ),
                  iconBackground: MenuItemSemantic.success.iconBackground(
                    Theme.of(context).brightness,
                  ),
                  title: '启动时检查更新',
                  subtitle: '仅前台启动时检测新版本',
                  value: vm.startupCheckEnabled.value,
                  onChanged: (v) => vm.startupCheckEnabled.value = v,
                ),
              ],
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 100.ms)
        .slideY(begin: 0.03, end: 0);
  }

  Widget _buildExperimentalSection(BuildContext context, ColorScheme cs) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Row(
                children: [
                  Text(
                    '实验性功能',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.outline,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Beta',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SettingsCard(
              colorScheme: cs,
              showDividers: true,
              children: [
                SettingsToggleTile(
                  icon: PhosphorIconsRegular.markdownLogo,
                  iconColor: MenuItemSemantic.experimental.iconColor(
                    Theme.of(context).brightness,
                  ),
                  iconBackground: MenuItemSemantic.experimental.iconBackground(
                    Theme.of(context).brightness,
                  ),
                  title: 'Markdown 笔记预览',
                  subtitle: '在笔记列表中渲染 Markdown 格式',
                  value: vm.markdownPreview.value,
                  onChanged: (v) => vm.markdownPreview.value = v,
                ),
              ],
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 150.ms)
        .slideY(begin: 0.03, end: 0);
  }

  Widget _buildLegalSection(BuildContext context, ColorScheme cs) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(label: '法律与合规', colorScheme: cs),
            SettingsCard(
              colorScheme: cs,
              showDividers: true,
              children: [
                SettingsNavigationTile(
                  icon: PhosphorIconsRegular.fileText,
                  iconColor: MenuItemSemantic.legal.iconColor(
                    Theme.of(context).brightness,
                  ),
                  iconBackground: MenuItemSemantic.legal.iconBackground(
                    Theme.of(context).brightness,
                  ),
                  title: '用户协议',
                  subtitle: '',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const UserAgreementPage(),
                    ),
                  ),
                ),
                SettingsNavigationTile(
                  icon: PhosphorIconsRegular.shieldCheck,
                  iconColor: MenuItemSemantic.legal.iconColor(
                    Theme.of(context).brightness,
                  ),
                  iconBackground: MenuItemSemantic.legal.iconBackground(
                    Theme.of(context).brightness,
                  ),
                  title: '隐私政策',
                  subtitle: '',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const PrivacyPolicyPage(),
                    ),
                  ),
                ),
                SettingsNavigationTile(
                  icon: PhosphorIconsRegular.code,
                  iconColor: MenuItemSemantic.legal.iconColor(
                    Theme.of(context).brightness,
                  ),
                  iconBackground: MenuItemSemantic.legal.iconBackground(
                    Theme.of(context).brightness,
                  ),
                  title: '开源许可证',
                  subtitle: 'Flutter / Rust / 第三方库许可',
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'Zephyr Reader',
                    applicationVersion: vm.appVersion.value,
                  ),
                ),
              ],
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 200.ms)
        .slideY(begin: 0.03, end: 0);
  }

  Widget _buildDangerSection(BuildContext context, ColorScheme cs) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                '危险操作',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.error.withValues(alpha: 0.8),
                  letterSpacing: 0.4,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: cs.error.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              child: Column(
                children: [
                  _dangerItem(
                    cs,
                    icon: PhosphorIconsRegular.arrowCounterClockwise,
                    title: '重置所有设置',
                    desc: '恢复默认排版、主题、同步配置',
                    onTap: () => _confirmResetSettings(context, cs),
                  ),
                  Container(
                    height: 0.5,
                    color: cs.error.withValues(alpha: 0.15),
                  ),
                  _dangerItem(
                    cs,
                    icon: PhosphorIconsRegular.trash,
                    title: '清除全部本地数据',
                    desc: '删除书籍、笔记、生词本、统计记录',
                    onTap: () => _confirmClearData(context, cs),
                  ),
                ],
              ),
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 250.ms)
        .slideY(begin: 0.03, end: 0);
  }

  Widget _dangerItem(
    ColorScheme cs, {
    required IconData icon,
    required String title,
    required String desc,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: cs.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: cs.error),
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
                      color: cs.error,
                    ),
                  ),
                  Text(
                    desc,
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(
              PhosphorIconsRegular.caretRight,
              size: 14,
              color: cs.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionFooter(
    BuildContext context,
    ColorScheme cs,
    String appVersion,
  ) {
    return Column(
      children: [
        Text(
          'Zephyr Reader $appVersion',
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: cs.outline),
        ),
        const SizedBox(height: 2),
        Text(
          'Flutter 3.41.2 · Rust 1.82.0 · FRB 2.12.0',
          style: TextStyle(
            fontSize: 10,
            color: cs.onSurfaceVariant.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () {},
              child: Text(
                '检查更新',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              ' · ',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ),
            GestureDetector(
              onTap: () {},
              child: Text(
                '反馈问题',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showLanguageSheet(BuildContext context, ColorScheme cs) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '界面语言',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              _langOption(context, cs, '跟随系统', null),
              const SizedBox(height: 8),
              _langOption(context, cs, '简体中文', 'zh'),
              const SizedBox(height: 8),
              _langOption(context, cs, 'English', 'en'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _langOption(
    BuildContext context,
    ColorScheme cs,
    String label,
    String? code,
  ) {
    final tm = ThemeManager.instance;
    return InkWell(
      onTap: () {
        tm.locale.value = code;
        vm.localeCode.value = code;
        vm.localeLabel.value = code == 'en' ? 'English' : '简体中文';
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      (code == null && tm.locale.value == null) ||
                          tm.locale.value == code
                      ? cs.primary
                      : cs.outlineVariant,
                  width: 2,
                ),
              ),
              child:
                  ((code == null && tm.locale.value == null) ||
                      tm.locale.value == code)
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmResetSettings(BuildContext context, ColorScheme cs) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(PhosphorIconsRegular.warning, size: 20, color: cs.error),
            const SizedBox(width: 8),
            const Text('确认重置', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Text('此操作将恢复排版、主题、同步配置等所有设置为默认值。\n\n不会删除书籍、笔记和生词数据。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () {
              Navigator.pop(ctx);
              vm.resetAllSettings();
            },
            child: const Text('确认重置'),
          ),
        ],
      ),
    );
  }

  void _confirmClearData(BuildContext context, ColorScheme cs) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(PhosphorIconsRegular.warning, size: 20, color: cs.error),
            const SizedBox(width: 8),
            const Text('清除所有数据', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: const Text(
          '此操作将删除所有书籍、笔记、生词本、阅读进度和统计记录。\n\n建议先通过 WebDAV 备份数据。\n\n此操作不可撤销。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () {
              Navigator.pop(ctx);
              vm.clearAllLocalData();
            },
            child: const Text('确认清除'),
          ),
        ],
      ),
    );
  }
}
