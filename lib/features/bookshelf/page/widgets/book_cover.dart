import 'dart:io';

import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/utils/cover_utils.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

// ─── Book Cover ─────────────────────────────────────────────────────────────

/// 统一书架封面组件，支持封面图/占位图、阅读状态标签、三角形进度覆盖+百分比。
class BookCover extends StatelessWidget {
  final Book book;
  final double? progress;
  final String? statusLabel;
  final double iconSize;
  final double titleFontSize;
  final int? cacheWidth;

  const BookCover({
    super.key,
    required this.book,
    this.progress,
    this.statusLabel,
    this.iconSize = 24,
    this.titleFontSize = 12,
    this.cacheWidth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final showProgress = progress != null && progress! > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Stack(
            children: [
              // Cover image / placeholder
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(
                    RadiusSize.sm.value,
                  ),
                ),
                child: book.coverPath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(
                          RadiusSize.sm.value,
                        ),
                        child: Image.file(
                          File(resolveCoverPath(book.coverPath!)!),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          cacheWidth: cacheWidth,
                          errorBuilder: (_, _, _) => _placeholder(cs),
                        ),
                      )
                    : _placeholder(cs),
              ),

              // Status tag - top-right (only when reading)
              if (statusLabel != null && book.status == BookStatus.reading)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusLabel!,
                      style: TextStyle(
                        fontSize: 10,
                        color: cs.onPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

              // Progress badge - bottom-right
              if (showProgress)
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${(progress! * 100).round()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          book.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: titleFontSize,
            color: cs.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _placeholder(ColorScheme cs) {
    return Center(
      child: Icon(
        PhosphorIconsRegular.book,
        size: iconSize,
        color: cs.primary.withValues(alpha: 0.4),
      ),
    );
  }

  /// 封面占位图标的独立 Widget，供英雄页等特殊布局复用。
  static Widget placeholder(ColorScheme cs, {double size = 48}) {
    return Center(
      child: Icon(
        PhosphorIconsRegular.book,
        size: size,
        color: cs.primary.withValues(alpha: 0.4),
      ),
    );
  }
}
