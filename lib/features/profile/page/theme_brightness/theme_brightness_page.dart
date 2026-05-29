import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/section_label.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_toggle_tile.dart';
import 'package:zephyr_reader/core/theme/menu_colors.dart';
import 'package:zephyr_reader/core/theme/theme_manager.dart';
import 'package:zephyr_reader/features/profile/page/theme_brightness/theme_brightness_view_model.dart';

class ThemeBrightnessPage extends HookWidget {
  final ThemeBrightnessViewModel vm;

  const ThemeBrightnessPage({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    useEffect(() {
      vm.initialize();
      return null;
    }, []);

    final cs = Theme.of(context).colorScheme;

    final int bgIndex = useSignalValue(vm.readerBgColorIndex);
    final AppThemeType themeType = useSignalValue(vm.themeType);
    final bool amoled = useSignalValue(vm.amoledMode);
    final int brightness = useSignalValue(vm.brightness);
    final bool useSystemBrightness = useSignalValue(vm.useSystemBrightness);
    final bool lowBatteryDim = useSignalValue(vm.lowBatteryDim);
    final bool reduceWhitePoint = useSignalValue(vm.reduceWhitePoint);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          '主题与亮度',
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
          _buildPreviewCard(cs, bgIndex),
          const SizedBox(height: 24),
          _buildAppThemeSection(cs, themeType, amoled),
          const SizedBox(height: 24),
          _buildBgColorSection(cs, bgIndex),
          const SizedBox(height: 24),
          _buildBrightnessSection(
            cs,
            brightness,
            useSystemBrightness,
            lowBatteryDim,
          ),
          const SizedBox(height: 24),
          _buildAdvancedSection(cs, amoled, reduceWhitePoint),
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
    bool amoled,
  ) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(label: '应用主题', colorScheme: cs),
            Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.2),
                  width: 0.5,
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _modeOption(
                    cs,
                    '浅色',
                    '☀️',
                    AppThemeType.light,
                    themeType,
                    amoled,
                  ),
                  const SizedBox(width: 8),
                  _modeOption(
                    cs,
                    '深色',
                    '🌙',
                    AppThemeType.dark,
                    themeType,
                    amoled,
                  ),
                  const SizedBox(width: 8),
                  _modeOption(
                    cs,
                    '跟随系统',
                    '🔄',
                    AppThemeType.system,
                    themeType,
                    amoled,
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
    String emoji,
    AppThemeType type,
    AppThemeType currentTheme,
    bool amoled,
  ) {
    final active =
        currentTheme == type ||
        (type == AppThemeType.dark &&
            currentTheme == AppThemeType.pureDark &&
            amoled);
    return Expanded(
      child: GestureDetector(
        onTap: () => vm.setThemeType(type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
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
              Text(emoji, style: const TextStyle(fontSize: 24)),
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

  Widget _buildBgColorPicker(ColorScheme cs, int activeIdx) {
    final colors = [
      const Color(0xFFFFFFFF),
      const Color(0xFFF5E6C8),
      const Color(0xFFFFF8E1),
      const Color(0xFFC8E6C9),
      const Color(0xFFECEFF1),
      const Color(0xFF000000),
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

  Widget _buildBrightnessSection(
    ColorScheme cs,
    int brightness,
    bool useSystemBrightness,
    bool lowBatteryDim,
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
                    iconColor: MenuItemSemantic.warning.iconColor,
                    iconBackground: MenuItemSemantic.warning.iconBackground,
                    title: '使用系统亮度',
                    subtitle: '关闭后可独立调节阅读器亮度',
                    value: useSystemBrightness,
                    onChanged: (v) => vm.setUseSystemBrightness(v),
                  ),
                  SettingsToggleTile(
                    icon: PhosphorIconsRegular.batteryLow,
                    iconColor: MenuItemSemantic.error.iconColor,
                    iconBackground: MenuItemSemantic.error.iconBackground,
                    title: '低电量自动降亮',
                    subtitle: '电量 < 20% 时自动降至 40%',
                    value: lowBatteryDim,
                    onChanged: (v) => vm.setLowBatteryDim(v),
                  ),
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
              const Text('🔆', style: TextStyle(fontSize: 16)),
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
                    fontSize: 13,
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
              activeTrackColor: const Color(0xFFFFD54F),
              inactiveTrackColor: const Color(0xFF333333),
              thumbColor: Colors.white,
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

  Widget _buildAdvancedSection(
    ColorScheme cs,
    bool amoled,
    bool reduceWhitePoint,
  ) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(label: '高级选项', colorScheme: cs),
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
                  SettingsToggleTile(
                    icon: PhosphorIconsRegular.circle,
                    iconColor: MenuItemSemantic.experimental.iconColor,
                    iconBackground:
                        MenuItemSemantic.experimental.iconBackground,
                    title: '纯黑 AMOLED 模式',
                    subtitle: '深色模式下使用 #000000 背景，节省 OLED 电量',
                    value: amoled,
                    onChanged: (v) => vm.setAmoledMode(v),
                  ),
                  SettingsToggleTile(
                    icon: PhosphorIconsRegular.moonStars,
                    iconColor: MenuItemSemantic.experimental.iconColor,
                    iconBackground:
                        MenuItemSemantic.experimental.iconBackground,
                    title: '降低白点值',
                    subtitle: '在系统最低亮度基础上进一步减弱强光刺激',
                    value: reduceWhitePoint,
                    onChanged: (v) => vm.setReduceWhitePoint(v),
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
}
