import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';
import 'package:zephyr_reader/core/theme/anim_tokens.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/core/reader/custom_font_service.dart';
import 'package:zephyr_reader/features/profile/application/tts_settings_view_model.dart';

/// 阅读器设置浮层面板类型。
enum ReaderPanelType {
  /// 排版：字体大小、行高、间距、边距
  typesetting,

  /// 显示：主题切换、背景色、亮度
  display,

  /// 更多：阅读模式、点按布局、书写方向、自动滚动
  more,

  /// 阅读辅助：朗读者 + 自动翻页
  assist,
}

/// 阅读器设置浮层面板。
///
/// 根据 [panelType] 展示不同功能区块，替代原来单一臃肿的设置面板。
class ReaderSettingsOverlay extends StatelessWidget {
  final ReaderPanelType panelType;
  final ReaderConfig config;
  final ReadingMode readingMode;
  final bool isTtsPlaying;
  final bool isTtsPaused;
  final ValueChanged<ReadingMode> onReadingModeChanged;
  final ValueChanged<double> onFontSizeChanged;
  final ValueChanged<double> onLineHeightChanged;
  final ValueChanged<double> onPageMarginChanged;
  final VoidCallback onTtsToggle;
  final VoidCallback onClose;
  final FontRepository fontRepo;
  final TtsSettingsViewModel ttsVm;

  const ReaderSettingsOverlay({
    super.key,
    required this.panelType,
    required this.config,
    required this.readingMode,
    required this.isTtsPlaying,
    required this.isTtsPaused,
    required this.onReadingModeChanged,
    required this.onFontSizeChanged,
    required this.onLineHeightChanged,
    required this.onPageMarginChanged,
    required this.onTtsToggle,
    required this.onClose,
    required this.ttsVm,
    required this.fontRepo,
  });

  @override
  Widget build(BuildContext context) {
    final readerTheme = Theme.of(context).extension<ReaderThemeExtension>()!;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: readerTheme.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandle(readerTheme),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.55,
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  ...switch (panelType) {
                    ReaderPanelType.typesetting => _buildTypesettingSection(
                      context,
                      readerTheme,
                      l10n,
                    ),
                    ReaderPanelType.display => _buildDisplaySection(
                      readerTheme,
                      l10n,
                    ),
                    ReaderPanelType.more => _buildMoreSection(
                      readerTheme,
                      l10n,
                    ),
                    ReaderPanelType.assist => _buildAssistSection(readerTheme, l10n),
                  },
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle(ReaderThemeExtension theme) {
    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
          onClose();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.mutedColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  // ── 排版 ──

  List<Widget> _buildTypesettingSection(
    BuildContext context,
    ReaderThemeExtension readerTheme,
    AppLocalizations l10n,
  ) {
    return [
      _sectionHeader(
        icon: PhosphorIconsRegular.textT,
        title: l10n.typographySection,
        mutedColor: readerTheme.mutedColor,
      ),
      _sliderTile(
        label: l10n.fontSize,
        value: config.fontSize.value,
        min: 12,
        max: 32,
        divisions: 20,
        display: '${config.fontSize.value.toStringAsFixed(0)}px',
        onChanged: onFontSizeChanged,
        readerTheme: readerTheme,
      ),
      _sliderTile(
        label: l10n.lineHeight,
        value: config.lineHeight.value,
        min: 0.7,
        max: 3.0,
        divisions: 23,
        display: config.lineHeight.value.toStringAsFixed(1),
        onChanged: onLineHeightChanged,
        readerTheme: readerTheme,
      ),
      _sliderTile(
        label: l10n.pageMargin,
        value: config.padding.value,
        min: 8,
        max: 40,
        divisions: 16,
        display: '${config.padding.value.toStringAsFixed(0)}px',
        onChanged: onPageMarginChanged,
        readerTheme: readerTheme,
      ),
      const SizedBox(height: 4),
      _textAlignSelector(readerTheme, l10n),
      const SizedBox(height: 2),
      _fontSelectionTile(readerTheme, l10n, () => _showFontSheet(context, readerTheme, l10n)),
      _readingModeSelectionTile(readerTheme, l10n, () => _showReadingModeSheet(context, readerTheme, l10n)),
    ];
  }

  String _readingModeLabel(AppLocalizations l10n) {
    return switch (readingMode) {
      ReadingMode.scroll => l10n.scrollMode,
      ReadingMode.pageTurn => l10n.pageTurnMode,
      ReadingMode.pagination => l10n.paginationMode,
      ReadingMode.bilingual => l10n.bilingualMode,
    };
  }

  Widget _fontSelectionTile(
    ReaderThemeExtension readerTheme,
    AppLocalizations l10n,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Icon(
              PhosphorIconsRegular.textT,
              size: 15,
              color: readerTheme.mutedColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.fontSelection,
                style: TextStyle(color: readerTheme.textColor, fontSize: 13),
              ),
            ),
            Text(
              fontRepo.currentFont.value?.displayName ?? '',
              style: TextStyle(color: readerTheme.mutedColor, fontSize: 11),
            ),
            const SizedBox(width: 4),
            Icon(
              PhosphorIconsRegular.caretRight,
              size: 14,
              color: readerTheme.mutedColor,
            ),
          ],
        ),
      ),
    );
  }

  void _showFontSheet(
    BuildContext context,
    ReaderThemeExtension readerTheme,
    AppLocalizations l10n,
  ) {
    final fonts = fontRepo.availableFonts.value;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.fontSelection,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: readerTheme.textColor,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: fonts.map((font) {
                  final isSelected = fontRepo.currentFont.value?.id == font.id;
                  return ListTile(
                    title: Text(
                      font.displayName,
                      style: TextStyle(color: readerTheme.textColor),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check, color: readerTheme.accentColor)
                        : null,
                    onTap: () {
                      fontRepo.setCurrentFont(font.id);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _readingModeSelectionTile(
    ReaderThemeExtension readerTheme,
    AppLocalizations l10n,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Icon(
              PhosphorIconsRegular.bookOpenText,
              size: 15,
              color: readerTheme.mutedColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.readingModeSection,
                style: TextStyle(color: readerTheme.textColor, fontSize: 13),
              ),
            ),
            Text(
              _readingModeLabel(l10n),
              style: TextStyle(color: readerTheme.mutedColor, fontSize: 11),
            ),
            const SizedBox(width: 4),
            Icon(
              PhosphorIconsRegular.caretRight,
              size: 14,
              color: readerTheme.mutedColor,
            ),
          ],
        ),
      ),
    );
  }

  void _showReadingModeSheet(
    BuildContext context,
    ReaderThemeExtension readerTheme,
    AppLocalizations l10n,
  ) {
    final accentColor = readerTheme.accentColor;
    final modes = [
      (ReadingMode.scroll, l10n.scrollMode, PhosphorIconsRegular.arrowsDownUp),
      (ReadingMode.pageTurn, l10n.pageTurnMode, PhosphorIconsRegular.book),
      (
        ReadingMode.pagination,
        l10n.paginationMode,
        PhosphorIconsFill.bookOpenText,
      ),
      (
        ReadingMode.bilingual,
        l10n.bilingualMode,
        PhosphorIconsRegular.translate,
      ),
    ];

    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.readingModeSection,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: readerTheme.textColor,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: modes.map((m) {
                  final isSelected = readingMode == m.$1;
                  return ListTile(
                    leading: Icon(m.$3, color: readerTheme.textColor),
                    title: Text(
                      m.$2,
                      style: TextStyle(color: readerTheme.textColor),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check, color: accentColor)
                        : null,
                    onTap: () {
                      onReadingModeChanged(m.$1);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 显示 ──

  List<Widget> _buildDisplaySection(
    ReaderThemeExtension readerTheme,
    AppLocalizations l10n,
  ) {
    return [
      _sectionHeader(
        icon: PhosphorIconsRegular.palette,
        title: l10n.appearanceSection,
        mutedColor: readerTheme.mutedColor,
      ),
      _sliderTile(
        label: l10n.brightness,
        value: 1 - config.brightnessOverlay.value,
        min: 0.3,
        max: 1.0,
        divisions: 14,
        display:
            '${((1 - config.brightnessOverlay.value) * 100).toStringAsFixed(0)}%',
        onChanged: (v) => config.brightnessOverlay.value = 1 - v,
        readerTheme: readerTheme,
      ),
      const SizedBox(height: 8),
      _themeSelector(readerTheme, l10n),
      const SizedBox(height: 12),
      _fontScaleTile(readerTheme, l10n),
      const SizedBox(height: 8),
      _bgColorPicker(readerTheme, l10n),
    ];
  }

  // ── 更多 ──

  List<Widget> _buildMoreSection(
    ReaderThemeExtension readerTheme,
    AppLocalizations l10n,
  ) {
    return [
      _sectionHeader(
        icon: PhosphorIconsRegular.handTap,
        title: l10n.tapLayout,
        mutedColor: readerTheme.mutedColor,
      ),
      _tapLayoutToggle(readerTheme, l10n),
      const SizedBox(height: 12),
      _sectionHeader(
        icon: PhosphorIconsRegular.paragraph,
        title: l10n.layoutSection,
        mutedColor: readerTheme.mutedColor,
      ),
      _writingDirectionSelector(readerTheme, l10n),
    ];
  }

  List<Widget> _buildAssistSection(
    ReaderThemeExtension readerTheme,
    AppLocalizations l10n,
  ) {
    return [
      _sectionHeader(
        icon: PhosphorIconsRegular.waveform,
        title: l10n.readingAssist,
        mutedColor: readerTheme.mutedColor,
      ),
      _ttsTile(readerTheme, l10n),
      _ttsSpeedSlider(readerTheme, l10n),
      _ttsAutoPageTile(readerTheme, l10n),
      _ttsOriginalOnlyTile(readerTheme, l10n),
      _autoScrollTile(readerTheme, l10n),
      _sliderTile(
        label: l10n.autoScrollSpeed,
        value: config.autoScrollSpeed.value.toDouble(),
        min: 10,
        max: 120,
        divisions: 22,
        display: '${config.autoScrollSpeed.value}s',
        onChanged: (v) => config.autoScrollSpeed.value = v.round(),
        readerTheme: readerTheme,
        enabled: config.autoScroll.value,
      ),
    ];
  }

  // ── TTS 快捷控制 ──

  Widget _ttsSpeedSlider(
    ReaderThemeExtension readerTheme,
    AppLocalizations l10n,
  ) {
    return _sliderTile(
      label: l10n.ttsSpeed,
      value: ttsVm.speed.value,
      min: 0.5,
      max: 2.0,
      divisions: 15,
      display: '${ttsVm.speed.value.toStringAsFixed(1)}x',
      onChanged: (v) => ttsVm.speed.value = v,
      readerTheme: readerTheme,
    );
  }

  Widget _ttsAutoPageTile(
    ReaderThemeExtension readerTheme,
    AppLocalizations l10n,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(
            PhosphorIconsRegular.arrowSquareRight,
            size: 15,
            color: readerTheme.mutedColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.ttsAutoPage,
              style: TextStyle(color: readerTheme.textColor, fontSize: 13),
            ),
          ),
          Switch(
            value: ttsVm.autoPage.value,
            onChanged: (v) => ttsVm.autoPage.value = v,
            activeThumbColor: readerTheme.accentColor,
          ),
        ],
      ),
    );
  }

  Widget _ttsOriginalOnlyTile(
    ReaderThemeExtension readerTheme,
    AppLocalizations l10n,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(
            PhosphorIconsRegular.translate,
            size: 15,
            color: readerTheme.mutedColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.ttsOriginalOnly,
              style: TextStyle(color: readerTheme.textColor, fontSize: 13),
            ),
          ),
          Switch(
            value: ttsVm.originalOnly.value,
            onChanged: (v) => ttsVm.originalOnly.value = v,
            activeThumbColor: readerTheme.accentColor,
          ),
        ],
      ),
    );
  }

  // ── 通用构建方法 ──

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required Color mutedColor,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
      child: Row(
        children: [
          Icon(icon, size: 15, color: mutedColor),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              color: mutedColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sliderTile({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String display,
    required ValueChanged<double> onChanged,
    required ReaderThemeExtension readerTheme,
    bool enabled = true,
  }) {
    final accentColor = readerTheme.accentColor;
    final textColor = readerTheme.textColor;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(color: enabled ? textColor : textColor.withValues(alpha: 0.25), fontSize: 13),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: accentColor,
                inactiveTrackColor: accentColor.withValues(alpha: 0.15),
                thumbColor: accentColor,
                overlayColor: accentColor.withValues(alpha: 0.1),
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              display,
              style: TextStyle(
                color: enabled ? textColor : textColor.withValues(alpha: 0.25),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }


  Widget _themeSelector(
    ReaderThemeExtension readerTheme,
    AppLocalizations l10n,
  ) {
    final accentColor = readerTheme.accentColor;
    final themes = [
      (ReaderTheme.light, l10n.readerThemeLight, PhosphorIconsRegular.sun),
      (ReaderTheme.sepia, l10n.readerThemeSepia, PhosphorIconsRegular.leaf),
      (ReaderTheme.dark, l10n.readerThemeDark, PhosphorIconsRegular.moon),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: themes.map((t) {
          final isSelected = config.theme.value == t.$1;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: GestureDetector(
                onTap: () => config.theme.value = t.$1,
                child: AnimatedContainer(
                  duration: AnimTokens.medium,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accentColor.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected
                          ? accentColor
                          : readerTheme.mutedColor.withValues(alpha: 0.2),
                      width: isSelected ? 1.5 : 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        t.$3,
                        size: 14,
                        color: isSelected
                            ? accentColor
                            : readerTheme.mutedColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        t.$2,
                        style: TextStyle(
                          color: isSelected
                              ? accentColor
                              : readerTheme.textColor,
                          fontSize: 12,
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
          );
        }).toList(),
      ),
    );
  }

  Widget _fontScaleTile(
    ReaderThemeExtension readerTheme,
    AppLocalizations l10n,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(
            PhosphorIconsRegular.textAa,
            size: 15,
            color: readerTheme.mutedColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.followSystemFontScale,
              style: TextStyle(color: readerTheme.textColor, fontSize: 13),
            ),
          ),
          Switch(
            value: config.followSystemFontScale.value,
            onChanged: (v) => config.followSystemFontScale.value = v,
            activeThumbColor: readerTheme.accentColor,
          ),
        ],
      ),
    );
  }

  Widget _tapLayoutToggle(
    ReaderThemeExtension readerTheme,
    AppLocalizations l10n,
  ) {
    final accentColor = readerTheme.accentColor;
    final layouts = [
      (
        TapLayout.rightHanded,
        l10n.tapLayoutRightHanded,
        PhosphorIconsRegular.handPointing,
      ),
      (
        TapLayout.leftHanded,
        l10n.tapLayoutLeftHanded,
        PhosphorIconsRegular.handFist,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: layouts.map((l) {
          final isSelected = config.tapLayout.value == l.$1;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: GestureDetector(
                onTap: () => config.tapLayout.value = l.$1,
                child: AnimatedContainer(
                  duration: AnimTokens.medium,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accentColor.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected
                          ? accentColor
                          : readerTheme.mutedColor.withValues(alpha: 0.2),
                      width: isSelected ? 1.5 : 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        l.$3,
                        size: 14,
                        color: isSelected
                            ? accentColor
                            : readerTheme.mutedColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l.$2,
                        style: TextStyle(
                          color: isSelected
                              ? accentColor
                              : readerTheme.textColor,
                          fontSize: 12,
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
          );
        }).toList(),
      ),
    );
  }

  Widget _writingDirectionSelector(
    ReaderThemeExtension readerTheme,
    AppLocalizations l10n,
  ) {
    final accentColor = readerTheme.accentColor;
    final directions = [
      (
        WritingDirection.horizontal,
        l10n.horizontal,
        PhosphorIconsRegular.textT,
      ),
      (WritingDirection.vertical, l10n.vertical, PhosphorIconsRegular.textAa),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: directions.map((d) {
          final isSelected = config.writingDirection.value == d.$1;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: GestureDetector(
                onTap: () => config.writingDirection.value = d.$1,
                child: AnimatedContainer(
                  duration: AnimTokens.medium,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? accentColor.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected
                          ? accentColor
                          : readerTheme.mutedColor.withValues(alpha: 0.2),
                      width: isSelected ? 1.5 : 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        d.$3,
                        size: 14,
                        color: isSelected
                            ? accentColor
                            : readerTheme.mutedColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        d.$2,
                        style: TextStyle(
                          color: isSelected
                              ? accentColor
                              : readerTheme.textColor,
                          fontSize: 12,
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
          );
        }).toList(),
      ),
    );
  }

  Widget _textAlignSelector(
    ReaderThemeExtension readerTheme,
    AppLocalizations l10n,
  ) {
    final accentColor = readerTheme.accentColor;
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              l10n.textAlign,
              style: TextStyle(color: readerTheme.textColor, fontSize: 13),
            ),
          ),
          Expanded(
            child: Row(
              children: options.map((o) {
                final isSelected = config.textAlign.value == o.$1;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: GestureDetector(
                      onTap: () => config.textAlign.value = o.$1,
                      child: AnimatedContainer(
                        duration: AnimTokens.medium,
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? accentColor.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected
                                ? accentColor
                                : readerTheme.mutedColor.withValues(alpha: 0.2),
                            width: isSelected ? 1.5 : 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              o.$3,
                              size: 14,
                              color: isSelected
                                  ? accentColor
                                  : readerTheme.mutedColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              o.$2,
                              style: TextStyle(
                                color: isSelected
                                    ? accentColor
                                    : readerTheme.textColor,
                                fontSize: 12,
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
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bgColorPicker(
    ReaderThemeExtension readerTheme,
    AppLocalizations l10n,
  ) {
    final presetColors = ReaderBgColors.presets;
    final accentColor = readerTheme.accentColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(presetColors.length, (i) {
          final isSelected = config.readerBgColorIndex.value == i;
          return GestureDetector(
            onTap: () => config.readerBgColorIndex.value = i,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: presetColors[i].withValues(alpha: 1.0),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                      ? accentColor
                      : readerTheme.mutedColor.withValues(alpha: 0.2),
                  width: isSelected ? 2.5 : 0.5,
                ),
              ),
              child: isSelected
                  ? Icon(
                      PhosphorIconsRegular.check,
                      size: 16,
                      color: accentColor,
                    )
                  : null,
            ),
          );
        }),
      ),
    );
  }

  Widget _autoScrollTile(
    ReaderThemeExtension readerTheme,
    AppLocalizations l10n,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(
            PhosphorIconsRegular.scroll,
            size: 15,
            color: readerTheme.mutedColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.autoScroll,
              style: TextStyle(color: readerTheme.textColor, fontSize: 13),
            ),
          ),
          Switch(
            value: config.autoScroll.value,
            onChanged: (v) => config.autoScroll.value = v,
            activeThumbColor: readerTheme.accentColor,
          ),
        ],
      ),
    );
  }

  Widget _ttsTile(ReaderThemeExtension readerTheme, AppLocalizations l10n) {
    final textColor = readerTheme.textColor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(
            isTtsPlaying || isTtsPaused
                ? PhosphorIconsRegular.speakerHigh
                : PhosphorIconsRegular.speakerNone,
            size: 15,
            color: isTtsPlaying || isTtsPaused
                ? readerTheme.ttsActiveColor
                : readerTheme.mutedColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.readAloud,
              style: TextStyle(color: textColor, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: onTtsToggle,
            style: TextButton.styleFrom(
              foregroundColor: readerTheme.accentColor,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              isTtsPlaying || isTtsPaused ? '停止' : '播放',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
