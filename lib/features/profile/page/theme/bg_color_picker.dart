import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/core/theme/anim_tokens.dart';

/// 阅读背景色选择器。
///
/// 水平滚动列表展示预设背景色和 AMOLED 纯黑色，支持点击切换。
/// 使用 [ReaderBgColors.presets] 中的预设颜色。
class BgColorPicker extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int> onSelected;

  const BgColorPicker({
    super.key,
    required this.activeIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = [
      ...ReaderBgColors.presets,
      const Color(0xFF000000), // AMOLED 纯黑
    ];
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: colors.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final active = i == activeIndex;
          return GestureDetector(
            onTap: () => onSelected(i),
            child: AnimatedContainer(
              duration: AnimTokens.fast,
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors[i],
                shape: BoxShape.circle,
                border: Border.all(
                  color: active ? cs.primary : Colors.transparent,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: cs.onSurface.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              transform: active
                  ? Matrix4.diagonal3Values(1.1, 1.1, 1)
                  : Matrix4.identity(),
              child: active
                  ? Center(
                      child: Icon(
                        PhosphorIconsRegular.check,
                        size: 20,
                        color: colors[i].computeLuminance() > 0.3
                            ? Colors.black54
                            : Colors.white70,
                      ),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}
