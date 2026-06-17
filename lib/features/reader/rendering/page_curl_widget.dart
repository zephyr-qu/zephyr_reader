import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/theme/anim_tokens.dart';

// ── Page Curl Widget ──

/// 仿真翻页组件。
///
/// 通过 ClipPath + Transform 实现页面卷曲效果，支持手指拖拽翻页和点击翻页。
/// 不依赖外部动画库，纯 Flutter CustomPainter 实现。
class PageCurlWidget extends StatefulWidget {
  final int pageIndex;
  final int totalPages;
  final Widget Function(int pageIndex) pageBuilder;
  final ValueChanged<int> onPageChanged;
  final bool isForward;
  final bool hasPreviousChapter;
  final VoidCallback? onReachStart;

  const PageCurlWidget({
    super.key,
    required this.pageIndex,
    required this.totalPages,
    required this.pageBuilder,
    required this.onPageChanged,
    this.isForward = true,
    this.hasPreviousChapter = false,
    this.onReachStart,
  });

  @override
  State<PageCurlWidget> createState() => _PageCurlWidgetState();
}

class _PageCurlWidgetState extends State<PageCurlWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late int _direction;
  double _dragProgress = 0.0;
  double _totalDx = 0.0;
  bool _committed = false;

  @override
  void initState() {
    super.initState();
    _direction = widget.isForward ? 1 : -1;
    _ctrl = AnimationController(vsync: this, duration: AnimTokens.slow)
      ..addListener(() => setState(() {}))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _onTurnCompleted();
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PageCurlWidget old) {
    super.didUpdateWidget(old);
    if (old.pageIndex != widget.pageIndex && !_ctrl.isAnimating) {
      _dragProgress = 0.0;
      _totalDx = 0.0;
      _committed = false;
    }
  }

  double get _progress => _ctrl.isAnimating ? _ctrl.value : _dragProgress;
  bool get _isForward => _direction == 1;

  bool get _canGoForward => widget.pageIndex < widget.totalPages - 1;
  bool get _canGoBackward =>
      widget.pageIndex > 0 ||
      (widget.pageIndex == 0 && widget.hasPreviousChapter);

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    if (_ctrl.isAnimating) return;

    setState(() {
      final delta = d.primaryDelta ?? 0.0;
      _totalDx += delta;

      if (_dragProgress < 0.001 && _totalDx.abs() > 2) {
        _direction = _totalDx > 0 ? -1 : 1;
        if (!(_isForward ? _canGoForward : _canGoBackward)) {
          _totalDx = 0;
          return;
        }
      }

      if (_dragProgress > 0 || _totalDx.abs() > 2) {
        final w = context.size?.width ?? 400;
        _dragProgress = (_totalDx.abs() / w).clamp(0.0, 1.0);
      }
    });
  }

  void _onHorizontalDragEnd(DragEndDetails d) {
    if (_ctrl.isAnimating || _dragProgress < 0.001) return;

    if (_dragProgress > 0.3) {
      _committed = true;
      _ctrl.forward(from: _dragProgress);
    } else {
      _ctrl.reverse(from: _dragProgress).then((_) {
        if (mounted) {
          setState(() {
            _dragProgress = 0.0;
            _totalDx = 0.0;
          });
        }
      });
    }
  }

  void _onTapUp(TapUpDetails d) {
    if (_ctrl.isAnimating) return;

    final size = context.size!;
    final third = size.width / 3;
    final isLeft = d.localPosition.dx < third;
    final isRight = d.localPosition.dx >= third * 2;

    if (isLeft && _canGoBackward) {
      _direction = -1;
      _committed = true;
      _ctrl.forward(from: 0);
    } else if (isRight && _canGoForward) {
      _direction = 1;
      _committed = true;
      _ctrl.forward(from: 0);
    }
  }

  void _onTurnCompleted() {
    if (!_committed) return;
    _committed = false;
    if (!_isForward && widget.pageIndex == 0 && widget.hasPreviousChapter) {
      widget.onReachStart?.call();
      if (mounted) {
        setState(() {
          _dragProgress = 0.0;
          _totalDx = 0.0;
        });
      }
      _ctrl.reset();
      return;
    }
    final newPage = _isForward ? widget.pageIndex + 1 : widget.pageIndex - 1;
    widget.onPageChanged(newPage);
    if (mounted) {
      setState(() {
        _dragProgress = 0.0;
        _totalDx = 0.0;
      });
    }
    _ctrl.reset();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    final showCurl = progress > 0;

    Widget? nextPage;
    if (showCurl) {
      final next = _isForward ? widget.pageIndex + 1 : widget.pageIndex - 1;
      if (next >= 0 && next < widget.totalPages) {
        nextPage = widget.pageBuilder(next);
      }
    }

    final currentPage = widget.pageBuilder(widget.pageIndex);

    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      onTapUp: _onTapUp,
      child: ClipRect(
        child: Stack(
          children: [
            // Next page (bottom layer)
            if (nextPage != null) Positioned.fill(child: nextPage),
            // Current page with clip & transform
            if (showCurl)
              ClipPath(
                clipper: _PageCurlClipper(
                  progress: progress,
                  isForward: _isForward,
                ),
                child: Transform(
                  alignment: _isForward
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(
                      _isForward ? (progress - 1) * 0.3 : (1 - progress) * 0.3,
                    ),
                  child: currentPage,
                ),
              )
            else
              currentPage,
            // Shadow overlay (on reveal side of fold)
            if (showCurl && nextPage != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _CurlShadowPainter(
                      progress: progress,
                      isForward: _isForward,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Page Curl Clipper ──

/// 裁剪当前页面为卷曲形状。
///
/// 在卷曲侧使用二次贝塞尔曲线模拟纸页弯曲。
class _PageCurlClipper extends CustomClipper<Path> {
  final double progress;
  final bool isForward;

  const _PageCurlClipper({required this.progress, required this.isForward});

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final foldX = isForward ? w * (1 - progress) : w * progress;
    final bulge = w * 0.08 * progress * (1 - progress);

    final path = Path();
    if (isForward) {
      // Right edge curls leftward — keep area left of fold
      path.moveTo(0, 0);
      path.lineTo(foldX, 0);
      path.quadraticBezierTo(foldX - bulge, h / 2, foldX, h);
      path.lineTo(0, h);
    } else {
      // Left edge curls rightward — keep area right of fold
      path.moveTo(w, 0);
      path.lineTo(foldX, 0);
      path.quadraticBezierTo(foldX + bulge, h / 2, foldX, h);
      path.lineTo(w, h);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_PageCurlClipper old) =>
      old.progress != progress || old.isForward != isForward;
}

// ── Curl Shadow Painter ──

/// 绘制卷曲边缘的阴影和折痕高光。
class _CurlShadowPainter extends CustomPainter {
  final double progress;
  final bool isForward;

  const _CurlShadowPainter({required this.progress, required this.isForward});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final foldX = isForward ? w * (1 - progress) : w * progress;
    final bulge = w * 0.08 * progress * (1 - progress);
    final shadowWidth = (bulge * 1.5).clamp(2.0, w * 0.3);

    // Shadow gradient on the revealed side of the fold
    final shadowRect = Rect.fromLTWH(
      isForward ? foldX - shadowWidth : foldX,
      0,
      shadowWidth,
      h,
    );

    final shadowPaint = Paint()
      ..shader = LinearGradient(
        begin: isForward ? Alignment.centerLeft : Alignment.centerRight,
        end: isForward ? Alignment.centerRight : Alignment.centerLeft,
        colors: [
          Colors.black.withValues(alpha: 0.2 * progress),
          Colors.black.withValues(alpha: 0.08 * progress),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(shadowRect);

    canvas.drawRect(shadowRect, shadowPaint);

    // Crease highlight line
    final creasePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12 * progress)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final creasePath = Path();
    if (isForward) {
      creasePath.moveTo(foldX, 0);
      creasePath.quadraticBezierTo(foldX - bulge * 0.5, h / 2, foldX, h);
    } else {
      creasePath.moveTo(foldX, 0);
      creasePath.quadraticBezierTo(foldX + bulge * 0.5, h / 2, foldX, h);
    }
    canvas.drawPath(creasePath, creasePaint);
  }

  @override
  bool shouldRepaint(_CurlShadowPainter old) =>
      old.progress != progress || old.isForward != isForward;
}
