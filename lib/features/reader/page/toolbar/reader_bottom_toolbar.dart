import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// 阅读器底部工具栏（五按钮功能面布局）。
///
///  目录 | 笔记 | 排版 | 显示 | 阅读辅助
class ReaderBottomToolbar extends StatelessWidget {
  final VoidCallback? onShowCatalog;
  final VoidCallback? onShowNotes;
  final VoidCallback? onToggleTypesetting;
  final VoidCallback? onToggleDisplay;
  final VoidCallback? onToggleAssist;

  const ReaderBottomToolbar({
    super.key,
    this.onShowCatalog,
    this.onShowNotes,
    this.onToggleTypesetting,
    this.onToggleDisplay,
    this.onToggleAssist,
  });

  @override
  Widget build(BuildContext context) {
    final readerTheme = Theme.of(context).extension<ReaderThemeExtension>()!;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      color: readerTheme.surfaceColor,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: _buildButton(
                icon: PhosphorIconsLight.listBullets,
                label: l10n.chapterList,
                onTap: onShowCatalog,
                color: readerTheme.textColor,
              ),
            ),
            Expanded(
              child: _buildButton(
                icon: PhosphorIconsLight.notePencil,
                label: l10n.selectionNote,
                onTap: onShowNotes,
                color: readerTheme.textColor,
              ),
            ),
            Expanded(
              child: _buildButton(
                icon: PhosphorIconsLight.textT,
                label: l10n.typographySection,
                onTap: onToggleTypesetting,
                color: readerTheme.textColor,
              ),
            ),
            Expanded(
              child: _buildButton(
                icon: PhosphorIconsLight.palette,
                label: l10n.appearanceSection,
                onTap: onToggleDisplay,
                color: readerTheme.textColor,
              ),
            ),
            Expanded(
              child: _buildButton(
                icon: PhosphorIconsLight.waveform,
                label: l10n.readingAssist,
                onTap: onToggleAssist,
                color: readerTheme.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 22, color: color),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
