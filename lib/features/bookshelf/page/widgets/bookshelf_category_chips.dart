import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/utils/adaptive_scroll_physics.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

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
              child: GestureDetector(
                onTap: () => onCategoryChanged(isSelected ? null : category),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary
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
