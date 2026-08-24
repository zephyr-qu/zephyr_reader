import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/section_label.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_card.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_toggle_tile.dart';
import 'package:zephyr_reader/core/theme/menu_colors.dart';
import 'package:zephyr_reader/core/theme/theme_manager.dart';
import 'package:zephyr_reader/features/profile/page/theme/brightness_slider.dart';
import 'package:zephyr_reader/features/profile/page/widgets/settings_app_bar.dart';
import 'package:zephyr_reader/features/profile/page/theme/theme_mode_option.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/features/profile/application/theme_brightness_view_model.dart';

/// 主题与亮度设置页面。
///
/// 提供浅色/深色/跟随系统主题切换、自定义主题色和自动主题切换配置。
/// 使用 [ThemeBrightnessViewModel] 管理设置状态。
class ThemeBrightnessPage extends HookWidget {
  const ThemeBrightnessPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = useMemoized(() => getIt<ThemeBrightnessViewModel>());
    final l10n = AppLocalizations.of(context)!;
    final AppThemeType themeType = useSignalValue(
      ThemeManager.instance.themeType.signal,
    );
    final int brightness = useSignalValue(vm.brightness.signal);
    final bool useSystemBrightness = useSignalValue(
      vm.useSystemBrightness.signal,
    );

    return Scaffold(
      appBar: SettingsAppBar(title: l10n.themeBrightness),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          _buildAppThemeSection(themeType, l10n, vm),
          const SizedBox(height: 16),
          _buildBrightnessSection(context, brightness, useSystemBrightness, vm),
          const SizedBox(height: 16),
          // 高级选项部分（reduceWhitePoint 已移除）
        ],
      ),
    );
  }

  Widget _buildAppThemeSection(
    AppThemeType themeType,
    AppLocalizations l10n,
    ThemeBrightnessViewModel vm,
  ) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(label: l10n.appTheme),
            SettingsCard(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      ThemeModeOption(
                        label: l10n.themeLight,
                        icon: PhosphorIconsRegular.sun,
                        type: AppThemeType.light,
                        currentTheme: themeType,
                        onTap: () => vm.setThemeType(AppThemeType.light),
                      ),
                      const SizedBox(width: 12),
                      ThemeModeOption(
                        label: l10n.themeDark,
                        icon: PhosphorIconsRegular.moon,
                        type: AppThemeType.dark,
                        currentTheme: themeType,
                        onTap: () => vm.setThemeType(AppThemeType.dark),
                      ),
                      const SizedBox(width: 12),
                      ThemeModeOption(
                        label: l10n.themeSystem,
                        icon: PhosphorIconsRegular.desktop,
                        type: AppThemeType.system,
                        currentTheme: themeType,
                        onTap: () => vm.setThemeType(AppThemeType.system),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 100.ms)
        .slideY(begin: 0.03, end: 0);
  }

  Widget _buildBrightnessSection(
    BuildContext context,
    int brightness,
    bool useSystemBrightness,
    ThemeBrightnessViewModel vm,
  ) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel(label: '亮度调节'),
            SettingsCard(
              showDividers: true,
              children: [
                BrightnessSlider(
                  value: brightness,
                  onChanged: vm.setBrightness,
                ),
                SettingsToggleTile(
                  icon: PhosphorIconsRegular.sunHorizon,
                  semantic: MenuItemSemantic.warning,
                  title: '使用系统亮度',
                  subtitle: '关闭后可独立调节阅读器亮度',
                  value: useSystemBrightness,
                  onChanged: (v) => vm.setUseSystemBrightness(v),
                ),
                // lowBatteryDim 设置已移除（对应 BatteryStateService 已删除）
              ],
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 200.ms)
        .slideY(begin: 0.03, end: 0);
  }
}
