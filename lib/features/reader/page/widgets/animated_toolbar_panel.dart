import 'package:flutter/material.dart';

class AnimatedToolbarPanel extends StatelessWidget {
  final bool visible;
  final double opacity;
  final double slideBeginY;
  final Widget child;

  const AnimatedToolbarPanel({
    super.key,
    required this.visible,
    this.opacity = 1.0,
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
