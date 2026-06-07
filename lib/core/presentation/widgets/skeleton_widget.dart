import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';

/// 骨架屏加载占位组件。
///
/// 在数据加载期间显示闪烁动画占位块，提升用户感知的加载体验。
class SkeletonWidget extends HookWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Duration maxShimmerDuration;

  const SkeletonWidget({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 4,
    this.maxShimmerDuration = const Duration(seconds: 3),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shimmerActive = useState(true);

    useEffect(() {
      if (!shimmerActive.value) return null;
      final timer = Timer(maxShimmerDuration, () {
        shimmerActive.value = false;
      });
      return timer.cancel;
    }, [maxShimmerDuration]);

    final skeleton = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
      ),
    );

    if (shimmerActive.value) {
      return skeleton
          .animate()
          .then(delay: 0.ms, duration: 1500.ms)
          .shimmer(
            color: DesignTokens.warmAccent.withValues(alpha: 0.12),
            size: 0.3,
          );
    }
    return skeleton;
  }
}

class SkeletonCard extends StatelessWidget {
  final double? width;
  final double? height;
  final int lineCount;
  final double lineHeight;
  final double spacing;
  final double borderRadius;

  const SkeletonCard({
    super.key,
    this.width,
    this.height,
    this.lineCount = 3,
    this.lineHeight = 14,
    this.spacing = 10,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
          width: width,
          height: height,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            color: theme.colorScheme.surface,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonWidget(height: 18, borderRadius: 4),
              const SizedBox(height: 12),
              ...List.generate(
                lineCount,
                (i) => Padding(
                  padding: EdgeInsets.only(
                    bottom: i < lineCount - 1 ? spacing : 0,
                  ),
                  child: SkeletonWidget(
                    height: lineHeight,
                    width: i == lineCount - 1 ? 0.6 : 1.0,
                    borderRadius: 4,
                  ),
                ),
              ),
            ],
          ),
        )
        .animate()
        .then(delay: 0.ms, duration: 1500.ms)
        .shimmer(
          color: DesignTokens.warmAccent.withValues(alpha: 0.15),
          size: 0.3,
        );
  }
}

class SkeletonGrid extends StatelessWidget {
  final int itemCount;
  final int crossAxisCount;
  final double aspectRatio;
  final double spacing;

  const SkeletonGrid({
    super.key,
    this.itemCount = 6,
    this.crossAxisCount = 2,
    this.aspectRatio = 0.8,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(spacing),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: aspectRatio,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context).colorScheme.surface,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest.withAlpha(100),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonWidget(height: 12, borderRadius: 3),
                      SizedBox(height: 6),
                      SkeletonWidget(height: 10, width: 0.5, borderRadius: 3),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
