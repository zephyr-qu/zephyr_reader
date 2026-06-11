import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// 阅读器骨架屏 — 替代 [CircularProgressIndicator] 的加载占位。
///
/// 模拟真实书页的段落层级结构，而非均匀线条堆砌：
/// - 章节标题（居中短条）
/// - 多段正文段落缩进排列，尾行收短
/// - 首段落首行有首字下沉色块（drop cap）
/// - 底部页面进度指示
/// - shimmer 扫光模拟纸张上文字逐渐浮现的感觉
class ReaderSkeleton extends StatelessWidget {
  final Color backgroundColor;
  final double pageMargin;
  final double fontSize;
  final double lineHeight;
  final Brightness brightness;

  const ReaderSkeleton({
    super.key,
    required this.backgroundColor,
    required this.pageMargin,
    required this.fontSize,
    required this.lineHeight,
    required this.brightness,
  });

  // ── 段落数据 ──
  // 正值 = 该行宽度比例；负值 = 首行缩进 + 该比例宽度
  // 每个子列表代表一个自然段
  static const List<List<double>> _paragraphs = [
    [0.35], // 0: 章节标题
    [-0.82, 0.95, 0.90, 0.95, 0.65], // 1: 5 行（含 drop cap）
    [-0.82, 0.95, 0.88, 0.55], // 2: 4 行
    [-0.78, 0.92, 0.45], // 3: 3 行
    [-0.82, 0.95, 0.92, 0.88, 0.90, 0.60], // 4: 6 行
    [-0.82, 0.82, 0.78], // 5: 3 行 — 末段，收尾
  ];

  @override
  Widget build(BuildContext context) {
    final lineH = fontSize * lineHeight;
    final barH = lineH * 0.72;
    final gap = lineH * 0.28;
    final paraGap = lineH * 0.55;
    final indentW = fontSize * 1.6;
    final headingBot = lineH * 0.9;
    final isDark = brightness == Brightness.dark;

    final items = <Widget>[];

    for (int p = 0; p < _paragraphs.length; p++) {
      final lines = _paragraphs[p];
      final isHeading = p == 0;
      final isLastPara = p == _paragraphs.length - 1;

      if (isHeading) {
        items.add(SizedBox(height: lineH * 0.5));
      }

      for (int l = 0; l < lines.length; l++) {
        final raw = lines[l];
        final indent = raw < 0;
        final w = raw.abs();

        if (p == 1 && l == 0) {
          // 首段首行：drop cap + 同行文字
          items.add(_dropCapRow(barH, gap, indentW));
          continue;
        }
        if (p == 1 && l == 1) {
          // 首段第二行：缩进补偿 drop cap 宽度
          items.add(_line(w, indent, indentW + barH + gap, barH, gap));
          continue;
        }

        items.add(_line(w, indent, indentW, barH, gap));
      }

      if (!isLastPara) {
        items.add(SizedBox(height: isHeading ? headingBot : paraGap));
      }
    }

    // 页码
    items.add(SizedBox(height: lineH * 1.0));
    items.add(_pageIndicator(barH * 0.5));
    items.insert(0, SizedBox(height: lineH * 0.4));

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: items,
    );

    return Container(
      color: backgroundColor,
      padding: EdgeInsets.all(pageMargin),
      child: Shimmer.fromColors(
        baseColor: isDark ? Colors.white10 : Colors.black12,
        highlightColor: isDark ? Colors.white38 : Colors.black38,
        period: const Duration(seconds: 2),
        child: body,
      ),
    );
  }

  // ── 普通行 ──
  Widget _line(double w, bool indent, double indentW, double barH, double gap) {
    final bar = Container(
      height: barH,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(3),
      ),
    );
    if (indent) {
      return Padding(
        padding: EdgeInsets.only(bottom: gap),
        child: Row(
          children: [
            SizedBox(width: indentW),
            Expanded(child: bar),
          ],
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: gap),
      child: FractionallySizedBox(widthFactor: w, child: bar),
    );
  }

  // ── 首字下沉行 ──
  Widget _dropCapRow(double barH, double gap, double indentW) {
    final dropSize = barH * 2 + gap;
    return Padding(
      padding: EdgeInsets.only(bottom: gap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: indentW),
          Container(
            width: dropSize,
            height: dropSize,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          SizedBox(width: gap),
          Expanded(
            child: Container(
              height: barH,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 页码指示 ──
  Widget _pageIndicator(double barH) {
    final c = Colors.white;
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 20, height: 1.5, color: c),
          const SizedBox(width: 8),
          Container(
            width: barH * 0.6,
            height: barH * 0.5,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: barH * 0.4,
            height: barH * 0.5,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Container(width: 20, height: 1.5, color: c),
        ],
      ),
    );
  }
}
