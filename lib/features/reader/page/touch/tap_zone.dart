import 'package:flutter/material.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:flutter/services.dart';

/// 全屏点击/滑动翻页区域。
///
/// 将屏幕分为左/中/右三区，根据 [tapLayout] 映射方向。
/// 支持点按翻页和水平滑动翻页。
class TapZone extends StatelessWidget {
  final TapLayout tapLayout;
  final int pageIndex;
  final int totalPages;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;
  final VoidCallback onCenterTap;

  const TapZone({
    super.key,
    required this.tapLayout,
    required this.pageIndex,
    required this.totalPages,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onCenterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTapUp: (details) {
          final w = context.size?.width ?? 1;
          final third = w / 3;
          final isLeftZone = details.localPosition.dx < third;
          final isRightZone = details.localPosition.dx >= third * 2;
          late final bool goBack, goForward;
          switch (tapLayout) {
            case TapLayout.rightHanded:
              goBack = isLeftZone;
              goForward = isRightZone;
            case TapLayout.leftHanded:
              goBack = isRightZone;
              goForward = isLeftZone;
          }
          if (goBack && pageIndex > 0) {
            onPreviousPage();
            HapticFeedback.lightImpact();
          } else if (goForward && pageIndex < totalPages - 1) {
            onNextPage();
            HapticFeedback.lightImpact();
          } else if (!goBack && !goForward) {
            onCenterTap();
          }
        },
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity == null) return;
          if (details.primaryVelocity! < -30) {
            onNextPage();
            HapticFeedback.lightImpact();
          } else if (details.primaryVelocity! > 30) {
            onPreviousPage();
            HapticFeedback.lightImpact();
          }
        },
      ),
    );
  }
}
