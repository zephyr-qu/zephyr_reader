import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/section_label.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_card.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_slider_tile.dart';
import 'package:zephyr_reader/core/reading/config/reader_config.dart';
import 'package:zephyr_reader/core/reading/config/reader_typography_defaults.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/profile/page/typography/font_tile.dart';
import 'package:zephyr_reader/features/profile/page/typography/typography_preview.dart';
import 'package:zephyr_reader/features/profile/page/widgets/settings_app_bar.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// 排版与字体设置页面。
///
/// 提供字体选择、字号、字重、页边距和阅读模式设置，全部映射到
/// [ReaderConfig] 持久化信号 —— 与阅读器内的设置面板共享同一份配置，
/// 修改后下一次打开阅读器即生效。
class TypographySettingsPage extends HookWidget {
  const TypographySettingsPage({super.key});

  /// 字体选项：id 与 Readium CSS 字体族名一致，familyName 供预览使用。
  static const _fontOptions = [
    (FontInfo(id: 'System', name: 'System'), ''),
    (FontInfo(id: 'Serif', name: 'Serif'), 'Noto Serif SC'),
    (FontInfo(id: 'Noto Serif SC', name: 'Noto Serif SC'), 'Noto Serif SC'),
  ];

  @override
  Widget build(BuildContext context) {
    final config = useMemoized(() => getIt<ReaderConfig>(), []);
    final l10n = AppLocalizations.of(context)!;
    final double fontSize = useSignalValue(config.fontSize.signal);
    final double fontWeight = useSignalValue(config.fontWeight.signal);
    final double padding = useSignalValue(config.padding.signal);
    final double lineHeight = useSignalValue(config.lineHeight.signal);
    final double letterSpacing = useSignalValue(config.letterSpacing.signal);
    final double paragraphSpacing = useSignalValue(
      config.paragraphSpacing.signal,
    );
    final double paragraphIndent = useSignalValue(
      config.paragraphIndent.signal,
    );
    final ReaderTextAlign textAlign = useSignalValue(config.textAlign.signal);
    final String fontFamily = useSignalValue(config.fontFamily.signal);
    final ReadingMode readingMode = useSignalValue(config.readingMode.signal);

    return Scaffold(
      appBar: SettingsAppBar(title: l10n.typographySettings),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          TypographyPreview(config: config),
          const SizedBox(height: 16),
          _buildFontSection(l10n, fontFamily, config),
          const SizedBox(height: 16),
          _buildTypographySection(
            l10n,
            fontSize,
            fontWeight,
            padding,
            lineHeight,
            letterSpacing,
            paragraphSpacing,
            paragraphIndent,
            config,
          ),
          const SizedBox(height: 16),
          _buildTextAlignSection(context, l10n, textAlign, config),
          const SizedBox(height: 16),
          _buildReadingModeSection(context, l10n, readingMode, config),
        ],
      ),
    );
  }

  Widget _buildFontSection(
    AppLocalizations l10n,
    String fontFamily,
    ReaderConfig config,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label: l10n.fontFamily),
        SettingsCard(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Row(
                children: _fontOptions.map((option) {
                  return FontTile(
                    font: option.$1,
                    isActive: fontFamily == option.$1.id,
                    familyName: option.$2,
                    onTap: () => config.fontFamily.value = option.$1.id,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypographySection(
    AppLocalizations l10n,
    double fontSize,
    double fontWeight,
    double padding,
    double lineHeight,
    double letterSpacing,
    double paragraphSpacing,
    double paragraphIndent,
    ReaderConfig config,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label: l10n.typographySection),
        SettingsCard(
          showDividers: true,
          children: [
            SettingsSliderTile(
              label: l10n.fontSize,
              value: '${fontSize.round()}%',
              current: fontSize,
              min: 80,
              max: 200,
              step: 5,
              onChanged: (v) => config.fontSize.value = v,
            ),
            SettingsSliderTile(
              label: l10n.fontWeight,
              value: '${fontWeight.round()}',
              current: fontWeight,
              min: ReaderTypographyDefaults.minFontWeight,
              max: ReaderTypographyDefaults.maxFontWeight,
              step: 100,
              onChanged: (v) => config.fontWeight.value = v,
            ),
            SettingsSliderTile(
              label: l10n.pageMargin,
              value: '${padding.round()}',
              current: padding,
              min: ReaderTypographyDefaults.minPadding,
              max: ReaderTypographyDefaults.maxPadding,
              step: 2,
              onChanged: (v) => config.padding.value = v,
            ),
            SettingsSliderTile(
              label: l10n.lineHeight,
              value: '${lineHeight.toStringAsFixed(1)}x',
              current: lineHeight,
              min: 1.0,
              max: 2.0,
              step: 0.1,
              onChanged: (v) => config.lineHeight.value = v,
            ),
            SettingsSliderTile(
              label: l10n.letterSpacing,
              value: '${letterSpacing.toStringAsFixed(2)}em',
              current: letterSpacing,
              min: ReaderTypographyDefaults.minLetterSpacing,
              max: ReaderTypographyDefaults.maxLetterSpacing,
              step: 0.05,
              onChanged: (v) => config.letterSpacing.value = v,
            ),
            SettingsSliderTile(
              label: l10n.paragraphSpacing,
              value: '${paragraphSpacing.toStringAsFixed(1)}em',
              current: paragraphSpacing,
              min: 0,
              max: ReaderTypographyDefaults.maxParagraphSpacing,
              step: 0.25,
              onChanged: (v) => config.paragraphSpacing.value = v,
            ),
            SettingsSliderTile(
              label: l10n.paragraphIndent,
              value: '${paragraphIndent.toStringAsFixed(1)}em',
              current: paragraphIndent,
              min: 0,
              max: ReaderTypographyDefaults.maxParagraphIndent,
              step: 0.25,
              onChanged: (v) => config.paragraphIndent.value = v,
            ),
          ],
        ),
      ],
    );
  }

  /// 文本对齐平铺选择器，选项与阅读页一致：跟随原书/左对齐/两端对齐。
  Widget _buildTextAlignSection(
    BuildContext context,
    AppLocalizations l10n,
    ReaderTextAlign textAlign,
    ReaderConfig config,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final options = [
      (ReaderTextAlign.auto, l10n.textAlignAuto, PhosphorIconsRegular.textAa),
      (
        ReaderTextAlign.left,
        l10n.textAlignLeft,
        PhosphorIconsRegular.textAlignLeft,
      ),
      (
        ReaderTextAlign.justify,
        l10n.textAlignJustify,
        PhosphorIconsRegular.textAlignJustify,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label: l10n.textAlignment),
        SettingsCard(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: options.map((option) {
                  final isSelected = textAlign == option.$1;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => config.textAlign.value = option.$1,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colorScheme.primary.withValues(alpha: 0.08)
                                  : colorScheme.onSurface.withValues(
                                      alpha: 0.03,
                                    ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? colorScheme.primary
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  option.$3,
                                  size: 16,
                                  color: isSelected
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  option.$2,
                                  style: TextStyle(
                                    color: isSelected
                                        ? colorScheme.primary
                                        : colorScheme.onSurface,
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
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
    );
  }

  Widget _buildReadingModeSection(
    BuildContext context,
    AppLocalizations l10n,
    ReadingMode readingMode,
    ReaderConfig config,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final options = [
      (
        ReadingMode.pagination,
        l10n.paginationMode,
        PhosphorIconsRegular.bookOpenText,
      ),
      (ReadingMode.scroll, l10n.scrollMode, PhosphorIconsRegular.arrowsDownUp),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label: l10n.readingMode),
        SettingsCard(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: options.map((option) {
                  final isSelected = readingMode == option.$1;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => config.readingMode.value = option.$1,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colorScheme.primary.withValues(alpha: 0.08)
                                  : colorScheme.onSurface.withValues(
                                      alpha: 0.03,
                                    ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? colorScheme.primary
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  option.$3,
                                  size: 16,
                                  color: isSelected
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  option.$2,
                                  style: TextStyle(
                                    color: isSelected
                                        ? colorScheme.primary
                                        : colorScheme.onSurface,
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
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
    );
  }
}
