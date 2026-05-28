import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/theme/theme_manager.dart';
import 'package:zephyr_reader/features/profile/page/theme_brightness/theme_brightness_view_model.dart';

class ThemeBrightnessPage extends StatefulWidget {
  const ThemeBrightnessPage({super.key});

  @override
  State<ThemeBrightnessPage> createState() => _ThemeBrightnessPageState();
}

class _ThemeBrightnessPageState extends State<ThemeBrightnessPage> {
  final _vm = ThemeBrightnessViewModel();

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
          '主题与亮度',
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
      body: Watch.builder(
        builder: (context) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            children: [
              _buildPreviewCard(cs),
              const SizedBox(height: 24),
              _buildAppThemeSection(cs),
              const SizedBox(height: 24),
              _buildBgColorSection(cs),
              const SizedBox(height: 24),
              _buildBrightnessSection(cs),
              const SizedBox(height: 24),
              _buildAdvancedSection(cs),
            ],
          );
        },
      ),
    );
  }

  // ==================== Live Preview ====================

  Widget _buildPreviewCard(ColorScheme cs) {
    return Watch.builder(
      builder: (context) {
        final bgIndex = _vm.readerBgColorIndex.value;
        final previewColors = _previewColors(context);
        final colors =
            previewColors[bgIndex.clamp(0, previewColors.length - 1)];
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
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
        );
      },
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.04, end: 0);
  }

  List<(Color, Color)> _previewColors(BuildContext context) {
    return [
      (const Color(0xFFFFFFFF), const Color(0xFF1D1D1F)),
      (const Color(0xFFF5E6C8), const Color(0xFF3E2723)),
      (const Color(0xFFFFF8E1), const Color(0xFF4E342E)),
      (const Color(0xFFC8E6C9), const Color(0xFF1B5E20)),
      (const Color(0xFFECEFF1), const Color(0xFF263238)),
      (const Color(0xFF000000), const Color(0xFF9E9E9E)),
    ];
  }

  // ==================== App Theme ====================

  Widget _buildAppThemeSection(ColorScheme cs) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('应用主题', cs),
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
                  _modeOption(cs, '浅色', '☀️', AppThemeType.light),
                  const SizedBox(width: 8),
                  _modeOption(cs, '深色', '🌙', AppThemeType.dark),
                  const SizedBox(width: 8),
                  _modeOption(cs, '跟随系统', '🔄', AppThemeType.system),
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
  ) {
    return Watch.builder(
      builder: (context) {
        final active =
            _vm.themeType.value == type ||
            (type == AppThemeType.dark &&
                _vm.themeType.value == AppThemeType.pureDark &&
                _vm.amoledMode.value);
        return Expanded(
          child: GestureDetector(
            onTap: () => _vm.setThemeType(type),
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
      },
    );
  }

  // ==================== Reading Background ====================

  Widget _buildBgColorSection(ColorScheme cs) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('阅读背景色', cs),
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
              child: Watch.builder(
                builder: (context) {
                  final activeIdx = _vm.readerBgColorIndex.value;
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
                          onTap: () => _vm.setReaderBgColorIndex(i),
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
                },
              ),
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 150.ms)
        .slideY(begin: 0.03, end: 0);
  }

  // ==================== Brightness ====================

  Widget _buildBrightnessSection(ColorScheme cs) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('亮度调节', cs),
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
                  _buildBrightnessSlider(cs),
                  _buildToggleItem(
                    cs,
                    icon: PhosphorIconsRegular.sunHorizon,
                    iconColor: const Color(0xFFF57C00),
                    iconBg: const Color(0xFFFFF3E0),
                    title: '使用系统亮度',
                    desc: '关闭后可独立调节阅读器亮度',
                    value: _vm.useSystemBrightness.value,
                    onChanged: (v) => _vm.setUseSystemBrightness(v),
                  ),
                  _buildToggleItem(
                    cs,
                    icon: PhosphorIconsRegular.batteryLow,
                    iconColor: const Color(0xFFD32F2F),
                    iconBg: const Color(0xFFFFEBEE),
                    title: '低电量自动降亮',
                    desc: '电量 < 20% 时自动降至 40%',
                    value: _vm.lowBatteryDim.value,
                    onChanged: (v) => _vm.setLowBatteryDim(v),
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

  Widget _buildBrightnessSlider(ColorScheme cs) {
    return Watch.builder(
      builder: (context) {
        final val = _vm.brightness.value;
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
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 12,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 20,
                  ),
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
                  onChanged: (v) => _vm.setBrightness(v.round()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== Advanced ====================

  Widget _buildAdvancedSection(ColorScheme cs) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('高级选项', cs),
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
                  _buildToggleItem(
                    cs,
                    icon: PhosphorIconsRegular.circle,
                    iconColor: const Color(0xFF1A1A1A),
                    iconBg: const Color(0xFFE0E0E0),
                    title: '纯黑 AMOLED 模式',
                    desc: '深色模式下使用 #000000 背景，节省 OLED 电量',
                    value: _vm.amoledMode.value,
                    onChanged: (v) => _vm.setAmoledMode(v),
                  ),
                  _buildToggleItem(
                    cs,
                    icon: PhosphorIconsRegular.moonStars,
                    iconColor: const Color(0xFF7B1FA2),
                    iconBg: const Color(0xFFF3E5F5),
                    title: '降低白点值',
                    desc: '在系统最低亮度基础上进一步减弱强光刺激',
                    value: _vm.reduceWhitePoint.value,
                    onChanged: (v) => _vm.setReduceWhitePoint(v),
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

  Widget _buildToggleItem(
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
