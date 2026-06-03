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
import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/features/profile/page/theme_brightness/theme_brightness_view_model.dart';

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
    final bool useSystemBrightness = useSignalValue(vm.useSystemBrightness.signal);
    final String? currentPresetId = useSignalValue(vm.currentPresetId);

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
          _buildPresetSection(cs, currentPresetId),
          const SizedBox(height: 24),
          _buildBrightnessSection(
            context,
            cs,
            brightness,
            useSystemBrightness,
          ),
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
            SectionLabel(label: l10n.appTheme, colorScheme: cs),
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
                  _modeOption(
                    cs,
                    l10n.themeLight,
                    PhosphorIconsRegular.sun,
                    AppThemeType.light,
                    themeType,
                  ),
                  const SizedBox(width: 12),
                  _modeOption(
                    cs,
                    l10n.themeDark,
                    PhosphorIconsRegular.moon,
                    AppThemeType.dark,
                    themeType,
                  ),
                  const SizedBox(width: 12),
                  _modeOption(
                    cs,
                    l10n.themeSystem,
                    PhosphorIconsRegular.desktop,
                    AppThemeType.system,
                    themeType,
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
  Widget _modeOption(
    ColorScheme cs,
    String label,
    IconData icon,
    AppThemeType type,
    AppThemeType currentTheme,
  ) {
    final active = currentTheme == type;
    final iconColor = active ? cs.primary : cs.onSurfaceVariant;
    return Expanded(
      child: GestureDetector(
        onTap: () => vm.setThemeType(type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: active
                ? cs.primary.withValues(alpha: 0.08)
                : cs.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? cs.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBgColorSection(ColorScheme cs, int activeIdx) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(label: '阅读背景色', colorScheme: cs),
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
              child: _buildBgColorPicker(cs, activeIdx),
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 150.ms)
        .slideY(begin: 0.03, end: 0);
  }

  /// 构建背景色选择器
  ///
  /// 使用 [ReaderBgColors.presets] 作为基础色板，额外添加 AMOLED 纯黑色。
  Widget _buildBgColorPicker(ColorScheme cs, int activeIdx) {
    final colors = [
      ...ReaderBgColors.presets,
      const Color(0xFF000000), // AMOLED 纯黑
    ];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: colors.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final active = i == activeIdx;
          return GestureDetector(
            onTap: () => vm.setReaderBgColorIndex(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors[i],
                shape: BoxShape.circle,
                border: Border.all(
                  color: active ? cs.primary : Colors.transparent,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: cs.onSurface.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              transform: active
                  ? Matrix4.diagonal3Values(1.1, 1.1, 1)
                  : Matrix4.identity(),
              child: active
                  ? Center(
                      child: Icon(
                        PhosphorIconsRegular.check,
                        size: 20,
                        color: colors[i].computeLuminance() > 0.3
                            ? Colors.black54
                            : Colors.white70,
                      ),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildPresetSection(ColorScheme cs, String? currentPresetId) {
    final presets = vm.presets;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label: '主题色', colorScheme: cs),
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
          child: SizedBox(
            height: 60,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: presets.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final preset = presets[i];
                final active = preset.id == currentPresetId;
                return GestureDetector(
                  onTap: () => vm.applyPreset(preset.id),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: active ? 52 : 48,
                        height: active ? 52 : 48,
                        decoration: BoxDecoration(
                          color: preset.primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: active ? cs.primary : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: cs.onSurface.withValues(alpha: 0.08),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        transform: active
                            ? Matrix4.diagonal3Values(1.1, 1.1, 1)
                            : Matrix4.identity(),
                        child: active
                            ? Center(
                                child: Icon(
                                  PhosphorIconsRegular.check,
                                  size: 20,
                                  color: preset.primaryColor
                                              .computeLuminance() >
                                          0.3
                                      ? Colors.black54
                                      : Colors.white70,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preset.name,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.03, end: 0);
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
            SectionLabel(label: '亮度调节', colorScheme: cs),
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
                  _buildBrightnessSlider(cs, brightness),
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

  Widget _buildBrightnessSlider(ColorScheme cs, int val) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIconsRegular.sun, size: 20, color: cs.onSurface),
              const SizedBox(width: 6),
              Text(
                '屏幕亮度',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$val%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              activeTrackColor: const Color(0xFFFFD54F), // 保留品牌色
              inactiveTrackColor: cs.onSurface.withValues(alpha: 0.12),
              thumbColor: cs.surface,
              overlayColor: cs.primary.withValues(alpha: 0.12),
            ),
            child: Slider(
              value: val.toDouble(),
              min: 30,
              max: 100,
              divisions: 70,
              label: '$val%',
              onChanged: (v) => vm.setBrightness(v.round()),
            ),
          ),
        ],
      ),
    );
  }
  // _buildAdvancedSection 已移除（reduceWhitePoint 设置无消费者）
}
