import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/section_label.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_card.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_navigation_tile.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_toggle_tile.dart';
import 'package:zephyr_reader/core/theme/menu_colors.dart';
import 'package:zephyr_reader/core/theme/theme_manager.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/profile/application/other_settings_view_model.dart';
import 'package:zephyr_reader/features/profile/page/other/lang_option_tile.dart';
import 'package:zephyr_reader/features/profile/page/other/legal_section.dart';
import 'package:zephyr_reader/features/profile/page/other/version_footer.dart';
import 'package:zephyr_reader/features/profile/page/widgets/settings_app_bar.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// 其他设置页面。
///
/// 提供学习目标、日间模式、阅读时长提醒、用户协议和隐私政策等入口。
/// 使用 [OtherSettingsViewModel] 管理设置状态。
class OtherSettingsPage extends HookWidget {
  const OtherSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = useMemoized(() => getIt<OtherSettingsViewModel>());
    useEffect(() {
      vm.initialize();
      return null;
    }, []);

    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final String? locale = useSignalValue(ThemeManager.instance.locale.signal);
    final localeLabel = locale == 'en' ? 'English' : '简体中文';
    // Previously in vm.appVersion signal — now loaded locally
    final appVersionState = useState<String>('');
    useEffect(() {
      PackageInfo.fromPlatform().then(
        (info) => appVersionState.value =
            'v${info.version} (Build ${info.buildNumber})',
      );
      return null;
    }, []);
    final appVersion = appVersionState.value;

    return Scaffold(
      appBar: SettingsAppBar(title: l10n.otherSettings),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          _buildBehaviorSection(context, cs, l10n, localeLabel, vm),
          const SizedBox(height: 16),
          _buildExperimentalSection(context, cs, l10n, vm),
          const SizedBox(height: 16),
          LegalSection(appVersion: appVersion),
          const SizedBox(height: 16),
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
    OtherSettingsViewModel vm,
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
                  semantic: MenuItemSemantic.info,
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
                  semantic: MenuItemSemantic.warning,
                  title: l10n.otherNotifications,
                  subtitle: l10n.otherNotificationsDesc,
                  value: vm.notificationsEnabled.value,
                  onChanged: (v) => vm.notificationsEnabled.value = v,
                ),
                SettingsToggleTile(
                  icon: PhosphorIconsRegular.arrowArcRight,
                  semantic: MenuItemSemantic.success,
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
    OtherSettingsViewModel vm,
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
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 150.ms)
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
                isSelected: ThemeManager.instance.locale.value == null,
                onTap: () {
                  ThemeManager.instance.locale.value = null;
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              LangOptionTile(
                label: l10n.chinese,
                isSelected: ThemeManager.instance.locale.value == 'zh',
                onTap: () {
                  ThemeManager.instance.locale.value = 'zh';
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              LangOptionTile(
                label: l10n.english,
                isSelected: ThemeManager.instance.locale.value == 'en',
                onTap: () {
                  ThemeManager.instance.locale.value = 'en';
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
