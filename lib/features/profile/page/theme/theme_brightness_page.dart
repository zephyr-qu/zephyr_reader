import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/section_label.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_toggle_tile.dart';
import 'package:zephyr_reader/core/theme/menu_colors.dart';
import 'package:zephyr_reader/core/theme/theme_manager.dart';
import 'package:zephyr_reader/features/profile/page/theme/bg_color_picker.dart';
import 'package:zephyr_reader/features/profile/page/theme/brightness_slider.dart';
import 'package:zephyr_reader/features/profile/page/theme/theme_mode_option.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/features/profile/application/theme_brightness_view_model.dart';

/// 主题与亮度设置页面。
///
/// 提供浅色/深色/跟随系统主题切换、自定义主题色和自动主题切换配置。
/// 使用 [ThemeBrightnessViewModel] 管理设置状态。
class ThemeBrightnessPage extends HookWidget {
  late final ThemeBrightnessViewModel vm = getIt<ThemeBrightnessViewModel>();

  ThemeBrightnessPage({super.key});

  @override
  Widget build(BuildContext context) {
    useEffect(() {
      vm.initialize();
      return null;
    }, []);

    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final int bgIndex = useSignalValue(vm.readerBgColorIndex);
    final AppThemeType themeType = useSignalValue(vm.themeType);
    final int brightness = useSignalValue(vm.brightness.signal);
    final bool useSystemBrightness = useSignalValue(
      vm.useSystemBrightness.signal,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.themeBrightness,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          _buildPreviewCard(cs, bgIndex),
          _buildAppThemeSection(cs, themeType, l10n),
          const SizedBox(height: 24),
          _buildBgColorSection(cs, bgIndex),
          const SizedBox(height: 24),
          _buildBrightnessSection(context, cs, brightness, useSystemBrightness),
          const SizedBox(height: 24),
          // 高级选项部分（reduceWhitePoint 已移除）
        ],
      ),
    );
  }

  Widget _buildPreviewCard(ColorScheme cs, int bgIndex) {
    final previewColors = _previewColors();
    final colors = previewColors[bgIndex.clamp(0, previewColors.length - 1)];
    final bg = colors.$1;
    final fg = colors.$2;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: bg.computeLuminance() > 0.5
              ? cs.outlineVariant.withValues(alpha: 0.15)
              : Colors.transparent,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                '春风又绿江南岸，明月何时照我还。',
                style: TextStyle(fontSize: 16, height: 1.8, color: fg),
              ),
              const SizedBox(height: 4),
              Text(
                'The spring wind has greened the southern shore again.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.8,
                  color: fg.withValues(alpha: 0.75),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: fg.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '实时预览',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: fg.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.04, end: 0);
  }

  List<(Color, Color)> _previewColors() {
    return [
      (const Color(0xFFFFFFFF), const Color(0xFF1D1D1F)),
      (const Color(0xFFF5E6C8), const Color(0xFF3E2723)),
      (const Color(0xFFFFF8E1), const Color(0xFF4E342E)),
      (const Color(0xFFC8E6C9), const Color(0xFF1B5E20)),
      (const Color(0xFFECEFF1), const Color(0xFF263238)),
      (const Color(0xFF000000), const Color(0xFF9E9E9E)),
    ];
  }

  Widget _buildAppThemeSection(
    ColorScheme cs,
    AppThemeType themeType,
    AppLocalizations l10n,
  ) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(label: l10n.appTheme),
            Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
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
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 100.ms)
        .slideY(begin: 0.03, end: 0);
  }

  Widget _buildBgColorSection(ColorScheme cs, int activeIdx) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel(label: '阅读背景色'),
            Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: BgColorPicker(
                activeIndex: activeIdx,
                onSelected: vm.setReaderBgColorIndex,
              ),
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 150.ms)
        .slideY(begin: 0.03, end: 0);
  }

  Widget _buildBrightnessSection(
    BuildContext context,
    ColorScheme cs,
    int brightness,
    bool useSystemBrightness,
  ) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel(label: '亮度调节'),
            Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              child: Column(
                children: [
                  BrightnessSlider(
                    value: brightness,
                    onChanged: vm.setBrightness,
                  ),
                  SettingsToggleTile(
                    icon: PhosphorIconsRegular.sunHorizon,
                    iconColor: MenuItemSemantic.warning.iconColor(
                      Theme.of(context).brightness,
                    ),
                    iconBackground: MenuItemSemantic.warning.iconBackground(
                      Theme.of(context).brightness,
                    ),
                    title: '使用系统亮度',
                    subtitle: '关闭后可独立调节阅读器亮度',
                    value: useSystemBrightness,
                    onChanged: (v) => vm.setUseSystemBrightness(v),
                  ),
                  // lowBatteryDim 设置已移除（对应 BatteryStateService 已删除）
                ],
              ),
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 200.ms)
        .slideY(begin: 0.03, end: 0);
  }
}
