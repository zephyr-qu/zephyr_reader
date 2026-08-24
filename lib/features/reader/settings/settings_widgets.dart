import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/reading/config/reader_config.dart';
import 'package:zephyr_reader/core/theme/anim_tokens.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

Widget buildHandle({
  required ReaderThemeExtension theme,
  required VoidCallback onClose,
}) {
  return SizedBox(
    height: 56,
    child: Stack(
      alignment: Alignment.center,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null &&
                details.primaryVelocity! > 300) {
              onClose();
            }
          },
          child: SizedBox(
            width: double.infinity,
            height: 56,
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
        ),
        Positioned(
          right: 4,
          child: IconButton(
            tooltip: '关闭',
            onPressed: onClose,
            icon: Icon(Icons.close, color: theme.textColor),
          ),
        ),
      ],
    ),
  );
}

Widget sectionHeader({
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

Widget sliderTile({
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
            style: TextStyle(
              color: enabled ? textColor : textColor.withValues(alpha: 0.25),
              fontSize: 13,
            ),
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

Widget themeSelector({
  required ReaderThemeExtension readerTheme,
  required AppLocalizations l10n,
  required ReaderConfig config,
  VoidCallback? onChanged,
}) {
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
              onTap: () {
                config.theme.value = t.$1;
                onChanged?.call();
              },
              child: AnimatedContainer(
                duration: AnimTokens.medium,
                constraints: const BoxConstraints(minHeight: 48),
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
                      color: isSelected ? accentColor : readerTheme.mutedColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      t.$2,
                      style: TextStyle(
                        color: isSelected ? accentColor : readerTheme.textColor,
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

Widget bgColorPicker({
  required ReaderThemeExtension readerTheme,
  required AppLocalizations l10n,
  required ReaderConfig config,
  required int selectedIndex,
  bool enabled = true,
  VoidCallback? onChanged,
}) {
  final presetColors = ReaderBgColors.presets;
  final accentColor = readerTheme.accentColor;

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(presetColors.length, (i) {
          final isSelected = selectedIndex == i;
          return GestureDetector(
            key: ValueKey('reader-bg-$i'),
            onTap: enabled
                ? () {
                    config.readerBgColorIndex.value = i;
                    onChanged?.call();
                  }
                : null,
            child: SizedBox.square(
              dimension: 48,
              child: Center(
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
              ),
            ),
          );
        }),
      ),
    ),
  );
}

Widget ttsTile({
  required ReaderThemeExtension readerTheme,
  required AppLocalizations l10n,
  required bool isTtsPlaying,
  required VoidCallback onTtsToggle,
}) {
  final textColor = readerTheme.textColor;
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Row(
      children: [
        Icon(
          isTtsPlaying
              ? PhosphorIconsRegular.speakerHigh
              : PhosphorIconsRegular.speakerNone,
          size: 15,
          color: isTtsPlaying
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
            isTtsPlaying ? '暂停' : '播放',
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    ),
  );
}
