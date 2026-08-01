import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// 阅读器底部四按钮工具栏。
///
/// 章节 | 文字排版 | 外观主题 | 阅读辅助
class ReaderBottomToolbar extends StatelessWidget {
  final ReaderThemeExtension readerTheme;
  final VoidCallback onShowCatalog;
  final VoidCallback onToggleTypesetting;
  final VoidCallback onToggleDisplay;
  final VoidCallback onToggleAssist;
  final bool isTtsPlaying;

  const ReaderBottomToolbar({
    super.key,
    required this.readerTheme,
    required this.onShowCatalog,
    required this.onToggleTypesetting,
    required this.onToggleDisplay,
    required this.onToggleAssist,
    required this.isTtsPlaying,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ColoredBox(
      color: readerTheme.surfaceColor,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              _ToolbarButton(
                icon: PhosphorIconsLight.listBullets,
                label: l10n.chapterList,
                color: readerTheme.textColor,
                onTap: onShowCatalog,
              ),
              _ToolbarButton(
                icon: PhosphorIconsLight.textT,
                label: l10n.typographySection,
                color: readerTheme.textColor,
                onTap: onToggleTypesetting,
              ),
              _ToolbarButton(
                icon: PhosphorIconsLight.palette,
                label: l10n.appearanceSection,
                color: readerTheme.textColor,
                onTap: onToggleDisplay,
              ),
              _ToolbarButton(
                icon: PhosphorIconsLight.waveform,
                label: l10n.readingAssist,
                color: isTtsPlaying
                    ? readerTheme.ttsActiveColor
                    : readerTheme.textColor,
                onTap: onToggleAssist,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Tooltip(
          message: label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 4,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 22, color: color),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color.withValues(alpha: 0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
