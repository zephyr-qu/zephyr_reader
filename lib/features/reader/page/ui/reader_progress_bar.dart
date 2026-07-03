import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/theme/reader_theme_extension.dart';

/// 阅读器底部拖拽进度条。
///
/// 显示当前页码/总页数，支持拖拽跳页。
@Deprecated('底部进度条已从阅读页移除，保留文件备查。')
class ReaderProgressBar extends StatelessWidget {
  final int pageIndex;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  @Deprecated('底部进度条已从阅读页移除，保留文件备查。')
  const ReaderProgressBar({
    super.key,
    required this.pageIndex,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final readerTheme = Theme.of(context).extension<ReaderThemeExtension>()!;
    final accentColor = readerTheme.accentColor;
    final mutedColor = readerTheme.mutedColor;
    final effective = totalPages > 1 ? totalPages : 1;
    final progress = (pageIndex + 1) / effective;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                activeTrackColor: accentColor,
                inactiveTrackColor: accentColor.withValues(alpha: 0.15),
                thumbColor: accentColor,
                overlayColor: accentColor.withValues(alpha: 0.1),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6,
                  elevation: 0,
                ),
              ),
              child: Slider(
                value: progress.clamp(0.0, 1.0),
                onChanged: (v) {
                  final target = (v * (totalPages - 1)).round().clamp(
                    0,
                    totalPages - 1,
                  );
                  onPageChanged(target);
                },
              ),
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              '${pageIndex + 1} / ${totalPages > 0 ? totalPages : '?'}',
              style: TextStyle(
                color: mutedColor,
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
}
