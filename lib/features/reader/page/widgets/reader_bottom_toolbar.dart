import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// 阅读器底部工具栏。
///
/// 提供目录、笔记、设置、TTS 朗读、翻页控制等操作按钮。
class ReaderBottomToolbar extends StatelessWidget {
  final int currentPageIndex;
  final int totalPages;
  final ThemeMode themeMode;
  final bool isTtsPlaying;
  final bool isTtsPaused;


  final VoidCallback? onShowCatalog;
  final VoidCallback? onShowNotes;
  final VoidCallback? onShowSettings;
  final VoidCallback? onTtsToggle;

  const ReaderBottomToolbar({
    super.key,
    required this.currentPageIndex,
    required this.totalPages,
    required this.themeMode,
    this.isTtsPlaying = false,
    this.isTtsPaused = false,
    this.onShowCatalog,
    this.onShowNotes,
    this.onShowSettings,
    this.onTtsToggle,
  });

  @override
  Widget build(BuildContext context) {
    final readerTheme = Theme.of(context).extension<ReaderThemeExtension>()!;
    final l10n = AppLocalizations.of(context)!;
    final textColor = readerTheme.textColor;
    final accentColor = readerTheme.accentColor;

    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  _BarButton(
                    icon: PhosphorIconsLight.listBullets,
                    onTap: onShowCatalog,
                    color: textColor,
                    tooltip: l10n.chapterList,
                  ),
                  _BarButton(
                    icon: PhosphorIconsLight.notePencil,
                    onTap: onShowNotes,
                    color: textColor,
                    tooltip: l10n.selectionNote,
                  ),
                  const Spacer(),
                  _ProgressBadge(
                    pageIndex: currentPageIndex,
                    totalPages: totalPages,
                    accentColor: accentColor,
                  ),
                  const Spacer(),
                  _BarButton(
                    icon: PhosphorIconsLight.gearSix,
                    onTap: onShowSettings,
                    color: accentColor,
                    tooltip: l10n.settings,
                  ),
                  _BarButton(
                    icon: isTtsPaused
                        ? PhosphorIconsLight.pause
                        : isTtsPlaying
                            ? PhosphorIconsLight.speakerHigh
                            : PhosphorIconsLight.speakerNone,
                    onTap: onTtsToggle,
                    color: isTtsPlaying || isTtsPaused
                        ? readerTheme.ttsActiveColor
                        : textColor,
                    tooltip: l10n.readAloud,
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

class _BarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final String? tooltip;

  const _BarButton({
    required this.icon,
    this.onTap,
    required this.color,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}

class _ProgressBadge extends StatelessWidget {
  final int pageIndex;
  final int totalPages;
  final Color accentColor;

  const _ProgressBadge({
    required this.pageIndex,
    required this.totalPages,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Text(
        '${pageIndex + 1} / ${totalPages > 0 ? totalPages : 1}',
        style: TextStyle(
          color: accentColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
