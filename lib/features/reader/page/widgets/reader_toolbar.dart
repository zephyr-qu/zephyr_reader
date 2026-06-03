library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';

class ReaderToolbar extends HookWidget {
  final String title;
  final String progress;
  final ThemeMode themeMode;
  final VoidCallback? onClose;
  final VoidCallback? onToggleToolbar;

  const ReaderToolbar({
    super.key,
    required this.title,
    this.progress = '',
    required this.themeMode,
    this.onClose,
    this.onToggleToolbar,
  });

  @override
  Widget build(BuildContext context) {
    final readerTheme = Theme.of(context).extension<ReaderThemeExtension>()!;
    final textColor = readerTheme.textColor;
    final accentColor = readerTheme.accentColor;

    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                const SizedBox(width: 4),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onClose,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Icon(
                      PhosphorIconsLight.caretLeft,
                      size: 20,
                      color: textColor,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: GestureDetector(
                    onTap: onToggleToolbar,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (progress.isNotEmpty)
                          Text(
                            progress,
                            style: TextStyle(
                              color: accentColor.withValues(alpha: 0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.3,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
