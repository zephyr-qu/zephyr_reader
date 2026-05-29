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
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: visible ? opacity : 0.0,
          duration: const Duration(milliseconds: 400),
          child: AnimatedScale(
            scale: visible ? 1.0 : 0.92,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            child: child,
          ),
        ),
      ),
    );
  }
}
