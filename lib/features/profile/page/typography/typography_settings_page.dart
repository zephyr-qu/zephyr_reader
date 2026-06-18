import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/section_label.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_card.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_slider_tile.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_toggle_tile.dart';
import 'package:zephyr_reader/features/reader/domain/service/custom_font_service.dart';
import 'package:zephyr_reader/features/reader/domain/model/font_info.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_typography_defaults.dart';
import 'package:zephyr_reader/src/rust/domain/types/typeset.dart';
import 'package:zephyr_reader/core/theme/menu_colors.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/profile/page/typography/font_tile.dart';
import 'package:zephyr_reader/features/profile/page/typography/reset_button.dart';
import 'package:zephyr_reader/features/profile/page/typography/typography_preview.dart';
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
          TypographyPreview(config: config, fontRepo: fontRepo),
          const SizedBox(height: 16),
          _buildFontGrid(context, cs, config, fontRepo),
          const SizedBox(height: 16),
          _buildSliders(context, cs, config),
          const SizedBox(height: 16),
          _buildTextAlign(context, cs, config),
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

  /// 仅重置排版页面管理的设置项，不触及主题、自动滚动、点击区域等其他页面管理的配置。
  Future<void> _reset(ReaderConfig config, FontRepository fontRepo) async {
    config.fontSize.value = ReaderTypographyDefaults.fontSize;
    config.lineHeight.value = ReaderTypographyDefaults.lineHeight;
    config.paragraphSpacing.value = ReaderTypographyDefaults.paragraphSpacing;
    config.padding.value = ReaderTypographyDefaults.padding;
    config.letterSpacing.value = ReaderTypographyDefaults.letterSpacing;
    config.punctuationSqueeze.value = true;
    config.textAlign.reset();
    config.baselineAlign.value = true;
    config.firstLineIndent.value = true;
    config.language.reset();
    config.autoSpaceRatio.reset();
    await fontRepo.setCurrentFont('system');
  }

  Widget _buildFontGrid(
    BuildContext context,
    ColorScheme cs,
    ReaderConfig config,
    FontRepository fontRepo,
  ) {
    final l10n = AppLocalizations.of(context)!;

    final FontInfo? currentFontInfo = useSignalValue(fontRepo.currentFont);
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
    final double fontSize = useSignalValue(config.fontSize.signal);
    final double lineHeight = useSignalValue(config.lineHeight.signal);
    final double padding = useSignalValue(config.padding.signal);
    final double letterSpacing = useSignalValue(config.letterSpacing.signal);
    final double paragraphSpacing = useSignalValue(
      config.paragraphSpacing.signal,
    );
    final double autoSpaceRatio = useSignalValue(config.autoSpaceRatio.signal);
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(label: l10n.typographyParams),
            SettingsCard(
              children: [
                SettingsSliderTile(
                  label: l10n.fontSize,
                  value: '${fontSize.toInt()}px',
                  current: fontSize,
                  min: 12,
                  max: 32,
                  onChanged: (v) => config.fontSize.value = v.roundToDouble(),
                ),
                SettingsSliderTile(
                  label: l10n.lineHeight,
                  value: lineHeight.toStringAsFixed(1),
                  current: lineHeight,
                  min: 1.0,
                  max: 2.5,
                  onChanged: (v) => config.lineHeight.value = v,
                  step: 0.1,
                ),
                SettingsSliderTile(
                  label: l10n.paragraphSpacing,
                  value: '${paragraphSpacing.toInt()}px',
                  current: paragraphSpacing,
                  min: 0,
                  max: 24,
                  onChanged: (v) =>
                      config.paragraphSpacing.value = v.roundToDouble(),
                  step: 2,
                ),
                SettingsSliderTile(
                  label: l10n.letterSpacing,
                  value: '${letterSpacing.toStringAsFixed(1)}px',
                  current: letterSpacing,
                  min: -0.5,
                  max: 2.0,
                  onChanged: (v) => config.letterSpacing.value = v,
                  step: 0.1,
                ),
                SettingsSliderTile(
                  label: l10n.pageMargin,
                  value: '${padding.toInt()}px',
                  current: padding,
                  min: 16,
                  max: 48,
                  onChanged: (v) => config.padding.value = v.roundToDouble(),
                  step: 2,
                ),
                SettingsSliderTile(
                  label: l10n.autoSpaceRatio,
                  value: '${(autoSpaceRatio * 100).toInt()}%',
                  current: autoSpaceRatio,
                  min: 0.0,
                  max: 1.0,
                  onChanged: (v) => config.autoSpaceRatio.value = v,
                  step: 0.05,
                ),
              ],
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 150.ms)
        .slideY(begin: 0.04, end: 0);
  }

  Widget _buildTextAlign(
    BuildContext context,
    ColorScheme cs,
    ReaderConfig config,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final TextAlign currentAlign = useSignalValue(config.textAlign.signal);
    final options = [
      (
        TextAlign.justify,
        l10n.textAlignJustify,
        PhosphorIconsRegular.textAlignCenter,
      ),
      (
        TextAlign.start,
        l10n.textAlignStart,
        PhosphorIconsRegular.textAlignLeft,
      ),
      (
        TextAlign.center,
        l10n.textAlignCenter,
        PhosphorIconsRegular.textAlignCenter,
      ),
      (TextAlign.end, l10n.textAlignEnd, PhosphorIconsRegular.textAlignRight),
    ];

    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(label: l10n.textAlign),
            SettingsCard(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: options.map((o) {
                      final isSelected = currentAlign == o.$1;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: GestureDetector(
                            onTap: () => config.textAlign.value = o.$1,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? cs.primary.withValues(alpha: 0.08)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? cs.primary
                                      : cs.outlineVariant.withValues(
                                          alpha: 0.3,
                                        ),
                                  width: isSelected ? 1.5 : 0.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    o.$3,
                                    size: 20,
                                    color: isSelected
                                        ? cs.primary
                                        : cs.onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    o.$2,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: isSelected
                                          ? cs.primary
                                          : cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 175.ms)
        .slideY(begin: 0.04, end: 0);
  }

  Widget _buildLanguageTile(BuildContext context, ReaderConfig config) {
    final l10n = AppLocalizations.of(context)!;
    final LanguageType currentLanguage = useSignalValue(config.language.signal);
    final options = [
      (LanguageType.auto, l10n.typesetLanguageAuto),
      (LanguageType.chinese, l10n.typesetLanguageChinese),
      (LanguageType.english, l10n.typesetLanguageEnglish),
      (LanguageType.mixed, l10n.typesetLanguageMixed),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.typesetLanguage,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: options.map((o) {
              final isSelected = currentLanguage == o.$1;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: () => config.language.value = o.$1,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant
                                    .withValues(alpha: 0.3),
                          width: isSelected ? 1.5 : 0.5,
                        ),
                      ),
                      child: Text(
                        o.$2,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedCjk(
    BuildContext context,
    ColorScheme cs,
    ReaderConfig config,
  ) {
    final l10n = AppLocalizations.of(context)!;
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
                  semantic: MenuItemSemantic.typography,
                  title: l10n.punctuationSqueeze,
                  subtitle: l10n.punctuationSqueezeDesc,
                  value: useSignalValue(config.punctuationSqueeze.signal),
                  onChanged: (v) => config.punctuationSqueeze.value = v,
                ),
                SettingsToggleTile(
                  icon: PhosphorIconsRegular.textAa,
                  semantic: MenuItemSemantic.typography,
                  title: l10n.baselineAlign,
                  subtitle: l10n.baselineAlignDesc,
                  value: useSignalValue(config.baselineAlign.signal),
                  onChanged: (v) => config.baselineAlign.value = v,
                ),
                SettingsToggleTile(
                  icon: PhosphorIconsRegular.textIndent,
                  semantic: MenuItemSemantic.typography,
                  title: l10n.firstLineIndent,
                  subtitle: l10n.firstLineIndentDesc,
                  value: useSignalValue(config.firstLineIndent.signal),
                  onChanged: (v) => config.firstLineIndent.value = v,
                ),
                _buildLanguageTile(context, config),
              ],
            ),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms, delay: 200.ms)
        .slideY(begin: 0.04, end: 0);
  }
}
