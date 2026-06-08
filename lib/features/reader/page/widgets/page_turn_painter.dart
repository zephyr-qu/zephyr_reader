import 'package:flutter/material.dart';

/// 翻页阴影绘制器。
///
/// 在仿真翻页模式中绘制页面边缘的卷曲阴影效果。
class PageTurnShadowPainter extends CustomPainter {
  final double opacity;
  final bool isForward;

  const PageTurnShadowPainter({required this.opacity, required this.isForward});

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;

    final paint = Paint()
      ..shader = LinearGradient(
        begin: isForward ? Alignment.centerLeft : Alignment.centerRight,
        end: isForward ? Alignment.centerRight : Alignment.centerLeft,
        colors: [
          Colors.black.withValues(alpha: opacity * 0.35),
          Colors.black.withValues(alpha: opacity * 0.15),
          Colors.black.withValues(alpha: opacity * 0.05),
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.6, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    if (opacity > 0.1) {
      final creasePaint = Paint()
        ..shader = LinearGradient(
          begin: isForward ? Alignment.centerLeft : Alignment.centerRight,
          end: isForward ? Alignment.centerRight : Alignment.centerLeft,
          colors: [
            Colors.black.withValues(alpha: opacity * 0.5),
            Colors.transparent,
          ],
          stops: const [0.0, 0.15],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        creasePaint,
      );
    }
  }

  @override
  bool shouldRepaint(PageTurnShadowPainter oldDelegate) =>
      oldDelegate.opacity != opacity || oldDelegate.isForward != isForward;
}

class PageTurnTransitionBuilder extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;
  final bool isForward;

  const PageTurnTransitionBuilder({
    super.key,
    required this.child,
    required this.animation,
    required this.isForward,
  });

  @override
  Widget build(BuildContext context) {
    final slideTween = Tween<Offset>(
      begin: isForward ? const Offset(0.25, 0) : const Offset(-0.25, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));

    return SlideTransition(
      position: slideTween,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final progress = animation.value;
          final angle = (1.0 - progress) * (-0.4);

          return Transform(
            alignment: isForward ? Alignment.centerLeft : Alignment.centerRight,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: Stack(
              children: [
                child!,
                Positioned.fill(
                  child: CustomPaint(
                    painter: PageTurnShadowPainter(
                      opacity: 1.0 - progress,
                      isForward: isForward,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        child: child,
      ),
    );
  }
}
