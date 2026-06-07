import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/utils/adaptive_scroll_physics.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 分类筛选标签栏。
///
/// 以横向滚动的标签形式展示书籍分类，支持选中分类筛选。
class BookshelfCategoryChips extends StatelessWidget {
  final List<Category> categories;
  final String? selectedCategoryId;
  final ValueChanged<Category?> onCategoryChanged;

  const BookshelfCategoryChips({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (categories.isEmpty) {
      return SizedBox(height: DesignTokens.spacing(Spacing.sm));
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        DesignTokens.spacing(Spacing.lg),
        10,
        DesignTokens.spacing(Spacing.lg),
        DesignTokens.spacing(Spacing.sm),
      ),
      child: SizedBox(
        height: 26,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: adaptiveScrollPhysics(context),
          itemCount: categories.length,
          separatorBuilder: (_, _) =>
              SizedBox(width: DesignTokens.spacing(Spacing.sm)),
          itemBuilder: (context, index) {
            final category = categories[index];
            final isSelected = selectedCategoryId == category.id;
            return RepaintBoundary(
              child: InkWell(
                onTap: () => onCategoryChanged(isSelected ? null : category),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? DesignTokens.warmAccent.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? DesignTokens.warmAccent
                          : theme.colorScheme.outlineVariant,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    category.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
