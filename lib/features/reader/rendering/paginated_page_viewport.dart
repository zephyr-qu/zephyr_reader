import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:zephyr_reader/core/utils/logging.dart';

/// 分页单页视口：固定高度 + 裁剪溢出，并吸收子树滚动手势。
class PaginatedPageViewport extends StatelessWidget {
  const PaginatedPageViewport({
    super.key,
    required this.maxHeight,
    required this.maxWidth,
    required this.child,
  });

  final double maxHeight;
  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: maxHeight,
      width: maxWidth,
      child: ClipRect(
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            scrollbars: false,
            dragDevices: const <PointerDeviceKind>{},
          ),
          child: NotificationListener<ScrollNotification>(
            onNotification: (_) => true,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Debug: measure actual content height vs viewport
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final renderBox = context.findRenderObject() as RenderBox?;
                  if (renderBox != null && renderBox.hasSize) {
                    Logging.info(
                      '[Viewport] maxH=${maxHeight.toStringAsFixed(0)} contentH=${renderBox.size.height.toStringAsFixed(0)} overflow=${(renderBox.size.height - maxHeight).toStringAsFixed(0)}',
                    );
                  }
                });
                return SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Align(alignment: Alignment.topCenter, child: child),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
