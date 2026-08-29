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
    final double fontSize = (useSignalValue(config.fontSize.signal) as double)
        .clamp(
          ReaderTypographyDefaults.minFontSize,
          ReaderTypographyDefaults.maxFontSize,
        )
        .toDouble();
    final double padding = (useSignalValue(config.padding.signal) as double)
        .clamp(
          ReaderTypographyDefaults.minPadding,
          ReaderTypographyDefaults.maxPadding,
        )
        .toDouble();
    final double lineHeight =
        (useSignalValue(config.lineHeight.signal) as double)
            .clamp(
              ReaderTypographyDefaults.minLineHeight,
              ReaderTypographyDefaults.maxLineHeight,
            )
            .toDouble();
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
            padding,
            lineHeight,
            config,
          ),
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
    double padding,
    double lineHeight,
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
              min: ReaderTypographyDefaults.minFontSize,
              max: ReaderTypographyDefaults.maxFontSize,
              step: 5,
              onChanged: (v) => config.fontSize.value = v,
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
              min: ReaderTypographyDefaults.minLineHeight,
              max: ReaderTypographyDefaults.maxLineHeight,
              step: 0.1,
              onChanged: (v) => config.lineHeight.value = v,
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
