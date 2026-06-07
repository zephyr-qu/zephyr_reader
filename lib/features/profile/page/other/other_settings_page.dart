import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/features/profile/page/widgets/settings_app_bar.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/section_label.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_card.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_navigation_tile.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_toggle_tile.dart';
import 'package:zephyr_reader/core/theme/menu_colors.dart';
import 'package:zephyr_reader/core/theme/theme_manager.dart';
import 'package:zephyr_reader/features/profile/application/other_settings_view_model.dart';
import 'package:zephyr_reader/features/profile/page/other/lang_option_tile.dart';
import 'package:zephyr_reader/features/profile/page/other/version_footer.dart';
import 'package:zephyr_reader/features/profile/page/privacy_policy_page.dart';
import 'package:zephyr_reader/features/profile/page/user_agreement_page.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/core/presentation/widgets/confirm_action_dialog.dart';
import 'package:zephyr_reader/core/presentation/widgets/danger_section.dart';

/// 其他设置页面。
///
/// 提供学习目标、日间模式、阅读时长提醒、用户协议和隐私政策等入口。
/// 使用 [OtherSettingsViewModel] 管理设置状态。
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
    final l10n = AppLocalizations.of(context)!;

    final String localeLabel = useSignalValue(vm.localeLabel);
    final String appVersion = useSignalValue(vm.appVersion);

    return Scaffold(
      appBar: SettingsAppBar(
        title: l10n.otherSettings,
        fontWeight: FontWeight.w800,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          _buildBehaviorSection(context, cs, l10n, localeLabel),
          const SizedBox(height: 24),
          _buildExperimentalSection(context, cs, l10n),
          const SizedBox(height: 24),
          _buildLegalSection(context, cs, l10n),
          const SizedBox(height: 24),
          _buildDangerSection(context, cs, l10n),
          const SizedBox(height: 24),
          VersionFooter(
            appVersion: appVersion,
            checkUpdateLabel: l10n.checkUpdate,
            feedbackLabel: l10n.feedback,
            onCheckUpdate: () {},
            onFeedback: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildBehaviorSection(
    BuildContext context,
    ColorScheme cs,
    AppLocalizations l10n,
    String localeLabel,
  ) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(label: l10n.otherBehavior),
            SettingsCard(
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
                  title: l10n.language,
                  subtitle: l10n.languageSubtitle,
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
                  onTap: () => _showLanguageSheet(context, l10n),
                ),
                SettingsToggleTile(
                  icon: PhosphorIconsRegular.bell,
                  iconColor: MenuItemSemantic.warning.iconColor(
                    Theme.of(context).brightness,
                  ),
                  iconBackground: MenuItemSemantic.warning.iconBackground(
                    Theme.of(context).brightness,
                  ),
                  title: l10n.otherNotifications,
                  subtitle: l10n.otherNotificationsDesc,
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
                  title: l10n.otherStartupCheck,
                  subtitle: l10n.otherStartupCheckDesc,
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

  Widget _buildExperimentalSection(
    BuildContext context,
    ColorScheme cs,
    AppLocalizations l10n,
  ) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Row(
                children: [
                  Text(
                    l10n.otherExperimental,
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
                  title: l10n.otherMarkdownPreview,
                  subtitle: l10n.otherMarkdownPreviewDesc,
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

  Widget _buildLegalSection(
    BuildContext context,
    ColorScheme cs,
    AppLocalizations l10n,
  ) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(label: l10n.otherLegal),
            SettingsCard(
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
                  title: l10n.userAgreement,
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
                  title: l10n.privacyPolicy,
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
                  title: l10n.openSourceLicense,
                  subtitle: l10n.openSourceLicenseDesc,
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

  Widget _buildDangerSection(
    BuildContext context,
    ColorScheme cs,
    AppLocalizations l10n,
  ) {
    return DangerSection(
          label: l10n.dangerZone,
          children: [
            DangerItem(
              icon: PhosphorIconsRegular.arrowCounterClockwise,
              title: l10n.resetAllSettings,
              description: l10n.resetAllSettingsDesc,
              onTap: () => _confirmResetSettings(context, cs),
            ),
            DangerItem(
              icon: PhosphorIconsRegular.trash,
              title: l10n.clearAllData,
              description: l10n.clearAllDataDesc,
              onTap: () => _confirmClearData(context, cs),
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 250.ms)
        .slideY(begin: 0.03, end: 0);
  }

  void _showLanguageSheet(BuildContext context, AppLocalizations l10n) {
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
              Text(
                l10n.language,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              LangOptionTile(
                label: l10n.followSystem,
                isSelected: vm.localeCode.value == null,
                onTap: () {
                  final tm = ThemeManager.instance;
                  tm.locale.value = null;
                  vm.localeCode.value = null;
                  vm.localeLabel.value = '简体中文';
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              LangOptionTile(
                label: l10n.chinese,
                isSelected: vm.localeCode.value == 'zh',
                onTap: () {
                  final tm = ThemeManager.instance;
                  tm.locale.value = 'zh';
                  vm.localeCode.value = 'zh';
                  vm.localeLabel.value = '简体中文';
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              LangOptionTile(
                label: l10n.english,
                isSelected: vm.localeCode.value == 'en',
                onTap: () {
                  final tm = ThemeManager.instance;
                  tm.locale.value = 'en';
                  vm.localeCode.value = 'en';
                  vm.localeLabel.value = 'English';
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmResetSettings(BuildContext context, ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    showConfirmActionDialog(
      context,
      title: l10n.confirmReset,
      content: l10n.confirmResetContent,
      confirmLabel: l10n.confirmReset,
      onConfirm: () => vm.resetAllSettings(),
    );
  }

  void _confirmClearData(BuildContext context, ColorScheme cs) {
    final l10n = AppLocalizations.of(context)!;
    showConfirmActionDialog(
      context,
      title: l10n.clearAllDataTitle,
      content: l10n.clearAllDataContent,
      confirmLabel: l10n.confirmClear,
      onConfirm: () => vm.clearAllLocalData(),
    );
  }
}
