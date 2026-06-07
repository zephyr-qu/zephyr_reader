import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/section_label.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_card.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_slider_tile.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_toggle_tile.dart';
import 'package:zephyr_reader/core/reader/custom_font_service.dart';
import 'package:zephyr_reader/core/reader/models/font_info.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/core/theme/menu_colors.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/profile/page/typography/font_tile.dart';
import 'package:zephyr_reader/features/profile/page/typography/reset_button.dart';
import 'package:zephyr_reader/features/profile/page/widgets/settings_app_bar.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// 排版设置页面。
///
/// 提供字体大小、行间距、字间距、页边距等阅读排版参数的调节。
class TypographySettingsPage extends HookWidget {
  const TypographySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final config = useMemoized(() => getIt<ReaderConfig>(), []);
    final fontRepo = useMemoized(() => getIt<FontRepository>(), []);
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: SettingsAppBar(title: l10n.typographySettings),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          _buildPreview(context, cs, config, fontRepo),
          const SizedBox(height: 24),
          _buildFontGrid(context, cs, config, fontRepo),
          const SizedBox(height: 24),
          _buildSliders(context, cs, config),
          const SizedBox(height: 24),
          _buildAdvancedCjk(context, cs, config),
          const SizedBox(height: 12),
          ResetButton(
            label: l10n.resetToDefault,
            onTap: () => _reset(config, fontRepo),
          ),
        ],
      ),
    );
  }

  String _fontFamily(FontRepository fontRepo, String fontId) {
    try {
      final font = fontRepo.availableFonts.value.firstWhere(
        (f) => f.id == fontId,
      );
      return fontRepo.familyNameFor(font);
    } catch (_) {
      return 'system-ui, sans-serif';
    }
  }

  /// 仅重置排版页面管理的设置项，不触及主题、自动滚动、点击区域等其他页面管理的配置。
  Future<void> _reset(ReaderConfig config, FontRepository fontRepo) async {
    config.fontSize.value = ReaderFontSize.medium.size;
    config.lineHeight.value = 1.6;
    config.paragraphSpacing.value = 16.0;
    config.padding.value = 16.0;
    config.letterSpacing.value = 0.0;
    config.punctuationSqueeze.value = true;
    config.baselineAlign.value = true;
    config.writingDirection.value = WritingDirection.horizontal;
    await fontRepo.setCurrentFont('system');
  }

  Widget _buildPreview(
    BuildContext context,
    ColorScheme cs,
    ReaderConfig config,
    FontRepository fontRepo,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final fontSize = useSignalValue<double, Signal<double>>(
      config.fontSize.signal,
    );
    final lineHeight = useSignalValue<double, Signal<double>>(
      config.lineHeight.signal,
    );
    final paragraphSpacing = useSignalValue<double, Signal<double>>(
      config.paragraphSpacing.signal,
    );
    final letterSpacing = useSignalValue<double, Signal<double>>(
      config.letterSpacing.signal,
    );
    final margin = useSignalValue<double, Signal<double>>(
      config.padding.signal,
    );
    final currentFontInfo = useSignalValue<FontInfo?, Signal<FontInfo?>>(
      fontRepo.currentFont,
    );
    final fontId = currentFontInfo?.id ?? 'system';

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
                l10n.livePreview,
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
                    fontFamily: _fontFamily(fontRepo, fontId),
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
                    fontFamily: _fontFamily(fontRepo, fontId),
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
    ReaderConfig config,
    FontRepository fontRepo,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final currentFontInfo = useSignalValue<FontInfo?, Signal<FontInfo?>>(
      fontRepo.currentFont,
    );
    final currentFontId = currentFontInfo?.id;
    final builtInFonts = fontRepo.availableFonts.value
        .where((f) => f.isBuiltIn)
        .toList();
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(label: l10n.fontSelection),
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
                  return FontTile(
                    font: font,
                    isActive: active,
                    familyName: fontRepo.familyNameFor(font),
                    onTap: () => fontRepo.setCurrentFont(font.id),
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
    ReaderConfig config,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label: l10n.typographyParams),
        SettingsCard(
          children: [
            SettingsSliderTile(
              label: l10n.fontSize,
              value:
                  '${useSignalValue<double, Signal<double>>(config.fontSize.signal).toInt()}px',
              current: useSignalValue<double, Signal<double>>(
                config.fontSize.signal,
              ),
              min: 12,
              max: 32,
              onChanged: (v) => config.fontSize.value = v.roundToDouble(),
            ),
            SettingsSliderTile(
              label: l10n.lineHeight,
              value: useSignalValue<double, Signal<double>>(
                config.lineHeight.signal,
              ).toStringAsFixed(1),
              current: useSignalValue<double, Signal<double>>(
                config.lineHeight.signal,
              ),
              min: 1.0,
              max: 2.5,
              onChanged: (v) => config.lineHeight.value = v,
              step: 0.1,
            ),
            SettingsSliderTile(
              label: l10n.paragraphSpacing,
              value:
                  '${useSignalValue<double, Signal<double>>(config.paragraphSpacing.signal).toInt()}px',
              current: useSignalValue<double, Signal<double>>(
                config.paragraphSpacing.signal,
              ),
              min: 0,
              max: 24,
              onChanged: (v) =>
                  config.paragraphSpacing.value = v.roundToDouble(),
              step: 2,
            ),
            SettingsSliderTile(
              label: l10n.letterSpacing,
              value:
                  '${useSignalValue<double, Signal<double>>(config.letterSpacing.signal).toStringAsFixed(1)}px',
              current: useSignalValue<double, Signal<double>>(
                config.letterSpacing.signal,
              ),
              min: -0.5,
              max: 2.0,
              onChanged: (v) => config.letterSpacing.value = v,
              step: 0.1,
            ),
            SettingsSliderTile(
              label: l10n.pageMargin,
              value:
                  '${useSignalValue<double, Signal<double>>(config.padding.signal).toInt()}px',
              current: useSignalValue<double, Signal<double>>(
                config.padding.signal,
              ),
              min: 16,
              max: 48,
              onChanged: (v) => config.padding.value = v.roundToDouble(),
              step: 2,
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 300.ms, delay: 150.ms).slideY(begin: 0.04, end: 0);
  }

  Widget _buildAdvancedCjk(
    BuildContext context,
    ColorScheme cs,
    ReaderConfig config,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final isVertical =
        useSignalValue<WritingDirection, Signal<WritingDirection>>(
          config.writingDirection,
        ) ==
        WritingDirection.vertical;
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Row(
                children: [
                  Text(
                    l10n.advancedTypography,
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
                      color: cs.brightness == Brightness.dark
                          ? const Color(0xFF4E2D0D)
                          : const Color(0xFFFFF3E0),
                    ),
                    child: Text(
                      l10n.cjkOptimization,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: cs.brightness == Brightness.dark
                            ? const Color(0xFFFFCC80)
                            : const Color(0xFFEF6C00),
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
                  icon: PhosphorIconsRegular.sliders,
                  iconColor: MenuItemSemantic.typography.iconColor(
                    Theme.of(context).brightness,
                  ),
                  iconBackground: MenuItemSemantic.typography.iconBackground(
                    Theme.of(context).brightness,
                  ),
                  title: l10n.punctuationSqueeze,
                  subtitle: l10n.punctuationSqueezeDesc,
                  value: useSignalValue<bool, Signal<bool>>(
                    config.punctuationSqueeze.signal,
                  ),
                  onChanged: (v) => config.punctuationSqueeze.value = v,
                ),
                SettingsToggleTile(
                  icon: PhosphorIconsRegular.textAa,
                  iconColor: MenuItemSemantic.typography.iconColor(
                    Theme.of(context).brightness,
                  ),
                  iconBackground: MenuItemSemantic.typography.iconBackground(
                    Theme.of(context).brightness,
                  ),
                  title: l10n.baselineAlign,
                  subtitle: l10n.baselineAlignDesc,
                  value: useSignalValue<bool, Signal<bool>>(
                    config.baselineAlign.signal,
                  ),
                  onChanged: (v) => config.baselineAlign.value = v,
                ),
                SettingsToggleTile(
                  icon: PhosphorIconsRegular.arrowDown,
                  iconColor: MenuItemSemantic.typography.iconColor(
                    Theme.of(context).brightness,
                  ),
                  iconBackground: MenuItemSemantic.typography.iconBackground(
                    Theme.of(context).brightness,
                  ),
                  title: l10n.verticalMode,
                  subtitle: l10n.verticalModeDesc,
                  value: isVertical,
                  onChanged: (v) => config.writingDirection.value = v
                      ? WritingDirection.vertical
                      : WritingDirection.horizontal,
                ),
              ],
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 200.ms)
        .slideY(begin: 0.04, end: 0);
  }
}
