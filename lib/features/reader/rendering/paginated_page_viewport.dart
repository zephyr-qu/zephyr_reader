import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/utils/logging.dart';

/// 分页单页视口：固定高度 + 裁剪溢出。DEBUG: 开启滚动以验证内容是否正好一页。
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
    Logging.info(
      '[PageViewport] maxH_dp=${maxHeight.toStringAsFixed(1)}'
      ' maxW_dp=${maxWidth.toStringAsFixed(1)}',
    );
    return SizedBox(
      height: maxHeight,
      width: maxWidth,
      child: ClipRect(
        child: SingleChildScrollView(
          child: Align(alignment: Alignment.topCenter, child: child),
        ),
      ),
    );
  }
}
