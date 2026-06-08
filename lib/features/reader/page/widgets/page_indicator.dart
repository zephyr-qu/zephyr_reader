import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 页面指示器（"当前页 / 总页数"）。
///
/// 在顶部面板和搜索栏均未显示时展示于底部居中位置。
/// 使用 [IgnorePointer] 使其不拦截触摸事件。
class PageIndicator extends StatelessWidget {
  final int pageIndex;
  final int totalPages;
  final bool visible;

  const PageIndicator({
    super.key,
    required this.pageIndex,
    required this.totalPages,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final effective = math.max(1, totalPages);
    return Positioned(
      bottom: 8,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${pageIndex + 1} / $effective',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
