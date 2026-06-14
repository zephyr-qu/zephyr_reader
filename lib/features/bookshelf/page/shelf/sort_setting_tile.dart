import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/theme/menu_colors.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/features/bookshelf/model/bookshelf_sort_type.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

class SortSettingTile extends StatelessWidget {
  final String label;
  final String dialogTitle;
  final BookshelfSortType currentSortType;
  final ValueChanged<BookshelfSortType> onChanged;

  const SortSettingTile({
    super.key,
    required this.label,
    required this.dialogTitle,
    required this.currentSortType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: MenuItemSemantic.neutral
                  .iconColor(brightness)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              PhosphorIconsRegular.arrowsDownUp,
              size: IconSize.inline,
              color: MenuItemSemantic.neutral.iconColor(brightness),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: cs.onSurface,
            ),
          ),
          const Spacer(),
          Material(
            color: DesignTokens.warmAccent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                final result = await showDialog<BookshelfSortType>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(dialogTitle),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: BookshelfSortType.values.map((type) {
                        return ListTile(
                          title: Text(type.l10nLabel(l10n)),
                          trailing: currentSortType == type
                              ? Icon(
                                  PhosphorIconsRegular.check,
                                  color: Theme.of(ctx).colorScheme.primary,
                                )
                              : null,
                          onTap: () => Navigator.pop(ctx, type),
                        );
                      }).toList(),
                    ),
                  ),
                );
                if (result != null) onChanged(result);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      PhosphorIconsRegular.sortAscending,
                      size: 14,
                      color: DesignTokens.warmAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      currentSortType.l10nLabel(l10n),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: DesignTokens.warmAccent,
                      ),
                    ),
                    Icon(
                      PhosphorIconsLight.caretRight,
                      size: 14,
                      color: DesignTokens.warmAccent.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
