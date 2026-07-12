/// 渲染 LayoutBuilder 实测的正文区尺寸（方案三）。
///
/// 装箱预算应尽量用这里的值，而不是 `MediaQuery` 估算——二者差一截就会整页留白。
abstract final class SpikeViewportMetrics {
  static double? contentWidthDp;
  static double? contentHeightDp;

  /// 与上次相差超过此值视为视口变化。
  static const double changeThresholdDp = 4;

  static void note({required double width, required double height}) {
    final w = width.clamp(1.0, 4096.0);
    final h = height.clamp(1.0, 8192.0);
    final prevW = contentWidthDp;
    final prevH = contentHeightDp;
    contentWidthDp = w;
    contentHeightDp = h;
    if (prevW == null ||
        prevH == null ||
        (prevW - w).abs() >= changeThresholdDp ||
        (prevH - h).abs() >= changeThresholdDp) {
      onChanged?.call(w, h);
    }
  }

  /// 视口变化回调（session / orchestrator 可挂一次重装箱）。
  static void Function(double width, double height)? onChanged;

  static void clear() {
    contentWidthDp = null;
    contentHeightDp = null;
  }
}
