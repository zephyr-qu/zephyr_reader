import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

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
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Align(alignment: Alignment.topCenter, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
