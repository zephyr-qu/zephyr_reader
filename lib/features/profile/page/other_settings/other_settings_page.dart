import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'package:zephyr_reader/core/theme/theme_manager.dart';
import 'package:zephyr_reader/features/profile/page/other_settings/other_settings_view_model.dart';
import 'package:zephyr_reader/features/profile/page/privacy_policy_page.dart';
import 'package:zephyr_reader/features/profile/page/user_agreement_page.dart';

class OtherSettingsPage extends StatefulWidget {
  const OtherSettingsPage({super.key});

  @override
  State<OtherSettingsPage> createState() => _OtherSettingsPageState();
}

class _OtherSettingsPageState extends State<OtherSettingsPage> {
  final _vm = OtherSettingsViewModel();

  @override
  void initState() {
    super.initState();
    _vm.initialize();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          '其他设置',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          _buildBehaviorSection(cs),
          const SizedBox(height: 24),
          _buildExperimentalSection(cs),
          const SizedBox(height: 24),
          _buildLegalSection(cs),
          const SizedBox(height: 24),
          _buildDangerSection(cs),
          const SizedBox(height: 24),
          _buildVersionFooter(cs),
        ],
      ),
    );
  }

  // ==================== App Behavior ====================

  Widget _buildBehaviorSection(ColorScheme cs) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('应用行为', cs),
            _settingsCard([
              _listItem(
                cs,
                icon: PhosphorIconsRegular.translate,
                iconColor: const Color(0xFF42A5F5),
                iconBg: const Color(0xFFE3F2FD),
                title: '界面语言',
                desc: '简体中文 / English',
                trailing: Watch.builder(
                  builder: (_) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _vm.localeLabel.value,
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
                    );
                  },
                ),
                onTap: () => _showLanguageSheet(cs),
              ),
              _toggleItem(
                cs,
                icon: PhosphorIconsRegular.bell,
                iconColor: const Color(0xFFEF6C00),
                iconBg: const Color(0xFFFFF3E0),
                title: '通知与提醒',
                desc: '阅读目标提醒、同步完成通知',
                value: _vm.notificationsEnabled.value,
                onChanged: (v) => _vm.setNotifications(v),
              ),
              _toggleItem(
                cs,
                icon: PhosphorIconsRegular.arrowArcRight,
                iconColor: const Color(0xFF43A047),
                iconBg: const Color(0xFFE8F5E9),
                title: '启动时检查更新',
                desc: '仅前台启动时检测新版本',
                value: _vm.startupCheckEnabled.value,
                onChanged: (v) => _vm.setStartupCheck(v),
              ),
            ]),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 100.ms)
        .slideY(begin: 0.03, end: 0);
  }

  // ==================== Experimental Features ====================

  Widget _buildExperimentalSection(ColorScheme cs) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Row(
                children: [
                  Text(
                    '实验性功能',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
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
            _settingsCard([
              _toggleItem(
                cs,
                icon: PhosphorIconsRegular.markdownLogo,
                iconColor: const Color(0xFF8E24AA),
                iconBg: const Color(0xFFF3E5F5),
                title: 'Markdown 笔记预览',
                desc: '在笔记列表中渲染 Markdown 格式',
                value: _vm.markdownPreview.value,
                onChanged: (v) => _vm.setMarkdownPreview(v),
              ),
              _toggleItem(
                cs,
                icon: PhosphorIconsRegular.paintBrush,
                iconColor: const Color(0xFF00838F),
                iconBg: const Color(0xFFE0F7FA),
                title: '自定义 CSS 注入',
                desc: '为 EPUB 内容注入用户样式表',
                value: _vm.customCss.value,
                onChanged: (v) => _vm.setCustomCss(v),
              ),
              _toggleItem(
                cs,
                icon: PhosphorIconsRegular.magnifyingGlass,
                iconColor: const Color(0xFF546E7A),
                iconBg: const Color(0xFFECEFF1),
                title: '高级搜索语法',
                desc: '支持 author: tag: regex: 等前缀',
                value: _vm.advancedSearch.value,
                onChanged: (v) => _vm.setAdvancedSearch(v),
              ),
            ]),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 150.ms)
        .slideY(begin: 0.03, end: 0);
  }

  // ==================== Legal & Compliance ====================

  Widget _buildLegalSection(ColorScheme cs) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('法律与合规', cs),
            _settingsCard([
              _listItem(
                cs,
                icon: PhosphorIconsRegular.fileText,
                iconColor: const Color(0xFF6D4C41),
                iconBg: const Color(0xFFEFEBE9),
                title: '用户协议',
                desc: '',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const UserAgreementPage(),
                  ),
                ),
              ),
              _listItem(
                cs,
                icon: PhosphorIconsRegular.shieldCheck,
                iconColor: const Color(0xFF6D4C41),
                iconBg: const Color(0xFFEFEBE9),
                title: '隐私政策',
                desc: '',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const PrivacyPolicyPage(),
                  ),
                ),
              ),
              _listItem(
                cs,
                icon: PhosphorIconsRegular.code,
                iconColor: const Color(0xFF6D4C41),
                iconBg: const Color(0xFFEFEBE9),
                title: '开源许可证',
                desc: 'Flutter / Rust / 第三方库许可',
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Zephyr Reader',
                  applicationVersion: _vm.appVersion.value,
                ),
              ),
            ]),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 200.ms)
        .slideY(begin: 0.03, end: 0);
  }

  // ==================== Danger Zone ====================

  Widget _buildDangerSection(ColorScheme cs) {
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
                    onTap: () => _confirmResetSettings(cs),
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
                    onTap: () => _confirmClearData(cs),
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

  // ==================== Version Footer ====================

  Widget _buildVersionFooter(ColorScheme cs) {
    return Watch.builder(
      builder: (context) {
        return Column(
          children: [
            Text(
              'Zephyr Reader ${_vm.appVersion.value}',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
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
      },
    );
  }

  // ==================== Dialogs ====================

  void _showLanguageSheet(ColorScheme cs) {
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
              _langOption(cs, '跟随系统', null),
              const SizedBox(height: 8),
              _langOption(cs, '简体中文', 'zh'),
              const SizedBox(height: 8),
              _langOption(cs, 'English', 'en'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _langOption(ColorScheme cs, String label, String? code) {
    final tm = ThemeManager.instance;
    return InkWell(
      onTap: () {
        tm.setLocale(code);
        _vm.localeCode.value = code;
        _vm.localeLabel.value = code == 'en' ? 'English' : '简体中文';
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

  void _confirmResetSettings(ColorScheme cs) {
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
              _vm.resetAllSettings();
            },
            child: const Text('确认重置'),
          ),
        ],
      ),
    );
  }

  void _confirmClearData(ColorScheme cs) {
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
              _vm.clearAllLocalData();
            },
            child: const Text('确认清除'),
          ),
        ],
      ),
    );
  }

  // ==================== Shared Widgets ====================

  Widget _sectionLabel(String label, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _settingsCard(List<Widget> children) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Column(
        children: List.generate(children.length, (i) {
          return Column(
            children: [
              if (i > 0)
                Divider(
                  height: 0.5,
                  color: cs.outlineVariant.withValues(alpha: 0.15),
                ),
              children[i],
            ],
          );
        }),
      ),
    );
  }

  Widget _listItem(
    ColorScheme cs, {
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String desc,
    Widget? trailing,
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
                color: iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: iconColor),
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
                  if (desc.isNotEmpty)
                    Text(
                      desc,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            trailing ??
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

  Widget _toggleItem(
    ColorScheme cs, {
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String desc,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.15),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
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
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(
            height: 24,
            child: Switch.adaptive(
              value: value,
              activeThumbColor: cs.primary,
              activeTrackColor: cs.primary.withValues(alpha: 0.3),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
