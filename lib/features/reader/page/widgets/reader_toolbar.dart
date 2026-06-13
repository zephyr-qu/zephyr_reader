import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';

/// 阅读器顶部工具栏。
///
/// 显示书名、阅读进度和关闭按钮，右侧放置更多功能入口。
class ReaderToolbar extends HookWidget {
  final String title;
  final String progress;
  final ThemeMode themeMode;
  final VoidCallback? onClose;
  final VoidCallback? onToggleToolbar;
  final VoidCallback? onToggleMore;
  final VoidCallback? onSearchBook;
  final VoidCallback? onToggleBookmarks;

  const ReaderToolbar({
    super.key,
    required this.title,
    this.progress = '',
    required this.themeMode,
    this.onClose,
    this.onToggleToolbar,
    this.onToggleMore,
    this.onSearchBook,
    this.onToggleBookmarks,
  });

  @override
  Widget build(BuildContext context) {
    final readerTheme = Theme.of(context).extension<ReaderThemeExtension>()!;
    final textColor = readerTheme.textColor;
    final accentColor = readerTheme.accentColor;

    return Container(
      color: readerTheme.surfaceColor,
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
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
            if (onSearchBook != null)
              GestureDetector(
                onTap: onSearchBook,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    PhosphorIconsLight.magnifyingGlass,
                    size: 20,
                    color: textColor,
                  ),
                ),
              ),
            if (onToggleBookmarks != null)
              GestureDetector(
                onTap: onToggleBookmarks,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    PhosphorIconsLight.bookmarkSimple,
                    size: 20,
                    color: textColor,
                  ),
                ),
              ),
            if (onToggleMore != null)
              GestureDetector(
                onTap: onToggleMore,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    PhosphorIconsLight.dotsThreeOutline,
                    size: 20,
                    color: textColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
