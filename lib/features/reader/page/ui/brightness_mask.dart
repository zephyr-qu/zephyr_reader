import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';

/// 亮度遮罩层。
///
/// 分页模式使用径向渐变（中心亮、边缘暗），
/// 滚动/双语模式使用顶部→底部线性渐变（顶部亮、底部暗）。
/// 双击可循环切换亮度预设档位。
class BrightnessMask extends StatelessWidget {
  final double brightness;
  final ReadingMode readingMode;
  final VoidCallback onDoubleTap;

  const BrightnessMask({
    super.key,
    required this.brightness,
    required this.readingMode,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    if (brightness <= 0) return const SizedBox.shrink();
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onDoubleTap: onDoubleTap,
      child: Container(
        decoration: BoxDecoration(
          gradient:
              readingMode == ReadingMode.scroll ||
                  readingMode == ReadingMode.bilingual
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: brightness),
                  ],
                  stops: const [0.35, 1.0],
                )
              : RadialGradient(
                  center: Alignment.center,
                  radius: 0.6,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: brightness * 0.5),
                    Colors.black.withValues(alpha: brightness),
                  ],
                  stops: const [0.3, 0.7, 1.0],
                ),
        ),
      ),
    );
  }
}
