import 'package:flutter/material.dart';

/// 生词统计条形图组件。
///
/// 显示某一状态生词的数量和占比进度条。
class VocabStatBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const VocabStatBar({
    super.key,
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final ratio = total > 0 ? count / total : 0.0;

    return Expanded(
      child: Column(
        children: [
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 60 * ratio.clamp(0.02, 1.0),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          Text(label, style: tt.labelSmall),
        ],
      ),
    );
  }
}
