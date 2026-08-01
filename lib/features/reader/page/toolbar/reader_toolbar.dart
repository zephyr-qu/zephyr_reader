import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';

/// 阅读器顶部工具栏：返回、书名和阅读进度。
class ReaderToolbar extends StatelessWidget {
  final String title;
  final String progress;
  final ReaderThemeExtension readerTheme;
  final VoidCallback onClose;

  const ReaderToolbar({
    super.key,
    required this.title,
    required this.progress,
    required this.readerTheme,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: readerTheme.surfaceColor,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const SizedBox(width: 4),
              IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: Icon(
                  PhosphorIconsLight.caretLeft,
                  size: 20,
                  color: readerTheme.textColor,
                ),
                onPressed: onClose,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: readerTheme.textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                    if (progress.isNotEmpty)
                      Text(
                        progress,
                        style: TextStyle(
                          color: readerTheme.accentColor.withValues(alpha: 0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.3,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }
}
