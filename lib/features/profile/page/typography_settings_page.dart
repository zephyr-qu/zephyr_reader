import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zephyr_reader/core/theme/menu_colors.dart';
import 'dart:async';

import 'package:zephyr_reader/di/service_locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/section_label.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_card.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_slider_tile.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_toggle_tile.dart';
import 'package:zephyr_reader/core/reader/custom_font_service.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';

class TypographySettingsPage extends HookWidget {
  late final ReaderConfig config = getIt<ReaderConfig>();
  late final FontRepository fontRepo = getIt<FontRepository>();

  TypographySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final fontSize = useState(18.0);
    final lineHeight = useState(1.6);
    final paragraphSpacing = useState(16.0);
    final letterSpacing = useState(0.0);
    final margin = useState(20.0);
    final currentFontId = useState('system');
    final punctuationSqueeze = useState(true);
    final baselineAlign = useState(true);
    final verticalMode = useState(false);
    final loaded = useState(false);

    useEffect(() {
      _loadSettings(
        fontSize,
        lineHeight,
        paragraphSpacing,
        letterSpacing,
        margin,
        punctuationSqueeze,
        baselineAlign,
        currentFontId,
        loaded,
      );
      return null;
    }, []);

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '排版与字体',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: loaded.value
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              children: [
                _buildPreview(
                  cs,
                  fontSize.value,
                  lineHeight.value,
                  paragraphSpacing.value,
                  letterSpacing.value,
                  margin.value,
                  currentFontId.value,
                ),
                const SizedBox(height: 24),
                _buildFontGrid(context, cs, currentFontId.value, currentFontId),
                const SizedBox(height: 24),
                _buildSliders(
                  context,
                  cs,
                  fontSize,
                  lineHeight,
                  paragraphSpacing,
                  letterSpacing,
                  margin,
                ),
                const SizedBox(height: 24),
                _buildAdvancedCjk(
                  context,
                  cs,
                  punctuationSqueeze,
                  baselineAlign,
                  verticalMode,
                ),
                const SizedBox(height: 12),
                _buildReset(
                  cs,
                  fontSize,
                  lineHeight,
                  paragraphSpacing,
                  letterSpacing,
                  margin,
                  punctuationSqueeze,
                  baselineAlign,
                  currentFontId,
                  loaded,
                ),
              ],
            )
          : Center(child: CircularProgressIndicator(color: cs.primary)),
    );
  }

  void _loadSettings(
    ValueNotifier<double> fontSize,
    ValueNotifier<double> lineHeight,
    ValueNotifier<double> paragraphSpacing,
    ValueNotifier<double> letterSpacing,
    ValueNotifier<double> margin,
    ValueNotifier<bool> punctuationSqueeze,
    ValueNotifier<bool> baselineAlign,
    ValueNotifier<String> currentFontId,
    ValueNotifier<bool> loaded,
  ) {
    fontSize.value = config.fontSize.value;
    lineHeight.value = config.lineHeight.value;
    paragraphSpacing.value = config.paragraphSpacing.value;
    letterSpacing.value = config.letterSpacing.value;
    margin.value = config.padding.value;
    punctuationSqueeze.value = config.punctuationSqueeze.value;
    currentFontId.value = fontRepo.currentFont.value?.id ?? 'system';

    loaded.value = true;
  }

  String _fontFamily(String fontId) {
    try {
      final font = fontRepo.availableFonts.value.firstWhere(
        (f) => f.id == fontId,
      );
      return fontRepo.familyNameFor(font);
    } catch (_) {
      return 'system-ui, sans-serif';
    }
  }

  Future<void> _selectFont(
    String id,
    ValueNotifier<String> currentFontId,
  ) async {
    currentFontId.value = id;
    await fontRepo.setCurrentFont(id);
  }

  Future<void> _reset(
    ValueNotifier<double> fontSize,
    ValueNotifier<double> lineHeight,
    ValueNotifier<double> paragraphSpacing,
    ValueNotifier<double> letterSpacing,
    ValueNotifier<double> margin,
    ValueNotifier<bool> punctuationSqueeze,
    ValueNotifier<bool> baselineAlign,
    ValueNotifier<String> currentFontId,
    ValueNotifier<bool> loaded,
  ) async {
    await config.resetToDefault();
    await fontRepo.setCurrentFont('system');
    _loadSettings(
      fontSize,
      lineHeight,
      paragraphSpacing,
      letterSpacing,
      margin,
      punctuationSqueeze,
      baselineAlign,
      currentFontId,
      loaded,
    );
  }

  Widget _buildPreview(
    ColorScheme cs,
    double fontSize,
    double lineHeight,
    double paragraphSpacing,
    double letterSpacing,
    double margin,
    String currentFontId,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(margin, 24, margin, 24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cs.onSurface.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '实时预览',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '春风又绿江南岸，明月何时照我还。',
                  style: TextStyle(
                    fontFamily: _fontFamily(currentFontId),
                    fontSize: fontSize * 1.05,
                    height: lineHeight,
                    letterSpacing: letterSpacing,
                    color: cs.onSurface,
                  ),
                ),
                SizedBox(height: paragraphSpacing),
                Text(
                  'The spring wind has greened the southern shore again.',
                  style: TextStyle(
                    fontFamily: _fontFamily(currentFontId),
                    fontSize: fontSize * 0.9,
                    height: lineHeight,
                    letterSpacing: letterSpacing,
                    color: cs.onSurface.withValues(alpha: 0.75),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.04, end: 0);
  }

  Widget _buildFontGrid(
    BuildContext context,
    ColorScheme cs,
    String currentFontId,
    ValueNotifier<String> currentFontIdNotifier,
  ) {
    final builtInFonts = fontRepo.availableFonts.value
        .where((f) => f.isBuiltIn)
        .toList();
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(
              label: '字体选择',
              colorScheme: Theme.of(context).colorScheme,
            ),
            Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.25),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: builtInFonts.map((font) {
                  final active = currentFontId == font.id;
                  final sampleChar = switch (font.id) {
                    'serif' => '宋',
                    'sans' => '黑',
                    _ => '永',
                  };
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _selectFont(font.id, currentFontIdNotifier),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: active
                              ? cs.primary.withValues(alpha: 0.08)
                              : cs.onSurface.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: active ? cs.primary : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              sampleChar,
                              style: TextStyle(
                                fontFamily: fontRepo.familyNameFor(font),
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: active ? cs.primary : cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              font.name,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: active
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: active
                                    ? cs.primary
                                    : cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 100.ms)
        .slideY(begin: 0.04, end: 0);
  }

  Widget _buildSliders(
    BuildContext context,
    ColorScheme cs,
    ValueNotifier<double> fontSize,
    ValueNotifier<double> lineHeight,
    ValueNotifier<double> paragraphSpacing,
    ValueNotifier<double> letterSpacing,
    ValueNotifier<double> margin,
  ) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(
              label: '排版参数',
              colorScheme: Theme.of(context).colorScheme,
            ),
            SettingsCard(
              colorScheme: Theme.of(context).colorScheme,
              children: [
                SettingsSliderTile(
                  label: '字号',
                  value: '${fontSize.value.toInt()}px',
                  current: fontSize.value,
                  min: 12,
                  max: 32,
                  onChanged: (v) => fontSize.value = v.roundToDouble(),
                  colorScheme: cs,
                ),
                SettingsSliderTile(
                  label: '行距',
                  value: lineHeight.value.toStringAsFixed(1),
                  current: lineHeight.value,
                  min: 1.0,
                  max: 2.5,
                  onChanged: (v) => lineHeight.value = v,
                  step: 0.1,
                  colorScheme: cs,
                ),
                SettingsSliderTile(
                  label: '段间距',
                  value: '${paragraphSpacing.value.toInt()}px',
                  current: paragraphSpacing.value,
                  min: 0,
                  max: 24,
                  onChanged: (v) => paragraphSpacing.value = v.roundToDouble(),
                  step: 2,
                  colorScheme: cs,
                ),
                SettingsSliderTile(
                  label: '字间距',
                  value: '${letterSpacing.value.toStringAsFixed(1)}px',
                  current: letterSpacing.value,
                  min: -0.5,
                  max: 2.0,
                  onChanged: (v) => letterSpacing.value = v,
                  step: 0.1,
                  colorScheme: cs,
                ),
                SettingsSliderTile(
                  label: '页边距',
                  value: '${margin.value.toInt()}px',
                  current: margin.value,
                  min: 16,
                  max: 48,
                  onChanged: (v) => margin.value = v.roundToDouble(),
                  step: 2,
                  colorScheme: cs,
                ),
              ],
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 150.ms)
        .slideY(begin: 0.04, end: 0);
  }

  Widget _buildAdvancedCjk(
    BuildContext context,
    ColorScheme cs,
    ValueNotifier<bool> punctuationSqueeze,
    ValueNotifier<bool> baselineAlign,
    ValueNotifier<bool> verticalMode,
  ) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Row(
                children: [
                  Text(
                    '高级排版',
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
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'CJK 优化',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFEF6C00),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SettingsCard(
              showDividers: true,
              colorScheme: Theme.of(context).colorScheme,
              children: [
                SettingsToggleTile(
                  icon: PhosphorIconsRegular.sliders,
                  iconColor: MenuItemSemantic.typography.iconColor(
                    Theme.of(context).brightness,
                  ),
                  iconBackground: MenuItemSemantic.typography.iconBackground(
                    Theme.of(context).brightness,
                  ),
                  title: '标点挤压',
                  subtitle: '减少中文标点符号周围的空白',
                  value: punctuationSqueeze.value,
                  onChanged: (v) => punctuationSqueeze.value = v,
                ),
                SettingsToggleTile(
                  icon: PhosphorIconsRegular.textAa,
                  iconColor: MenuItemSemantic.typography.iconColor(
                    Theme.of(context).brightness,
                  ),
                  iconBackground: MenuItemSemantic.typography.iconBackground(
                    Theme.of(context).brightness,
                  ),
                  title: '中西文基线对齐',
                  subtitle: '强制统一行高，避免混排时文字跳动',
                  value: baselineAlign.value,
                  onChanged: (v) => baselineAlign.value = v,
                ),
                SettingsToggleTile(
                  icon: PhosphorIconsRegular.arrowDown,
                  iconColor: MenuItemSemantic.typography.iconColor(
                    Theme.of(context).brightness,
                  ),
                  iconBackground: MenuItemSemantic.typography.iconBackground(
                    Theme.of(context).brightness,
                  ),
                  title: '竖排模式',
                  subtitle: '从右向左阅读，适合古籍排版',
                  value: verticalMode.value,
                  onChanged: (v) => verticalMode.value = v,
                ),
              ],
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 200.ms)
        .slideY(begin: 0.04, end: 0);
  }

  Widget _buildReset(
    ColorScheme cs,
    ValueNotifier<double> fontSize,
    ValueNotifier<double> lineHeight,
    ValueNotifier<double> paragraphSpacing,
    ValueNotifier<double> letterSpacing,
    ValueNotifier<double> margin,
    ValueNotifier<bool> punctuationSqueeze,
    ValueNotifier<bool> baselineAlign,
    ValueNotifier<String> currentFontId,
    ValueNotifier<bool> loaded,
  ) {
    return Center(
      child: TextButton(
        onPressed: () => _reset(
          fontSize,
          lineHeight,
          paragraphSpacing,
          letterSpacing,
          margin,
          punctuationSqueeze,
          baselineAlign,
          currentFontId,
          loaded,
        ),
        child: Text(
          '恢复默认设置',
          style: TextStyle(
            fontSize: 13,
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
