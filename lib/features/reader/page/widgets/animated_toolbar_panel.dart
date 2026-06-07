import 'package:flutter/material.dart';

/// 带动画的工具栏面板容器。
///
/// 提供显隐切换的滑动动画效果。
class AnimatedToolbarPanel extends StatelessWidget {
  final bool visible;
  final double slideBeginY;
  final Widget child;

  const AnimatedToolbarPanel({
    super.key,
    required this.visible,
    this.slideBeginY = 0,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedSlide(
        offset: visible ? Offset.zero : Offset(0, slideBeginY),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        child: child,
      ),
    );
  }
}
