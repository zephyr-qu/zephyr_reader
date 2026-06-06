import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zephyr_reader/core/theme/menu_colors.dart';
import 'package:zephyr_reader/core/theme/theme_extension.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

// --- Data classes ---

class MenuSectionData {
  final String label;
  final List<MenuItemData> items;
  const MenuSectionData(this.label, this.items);
}

class MenuItemData {
  final IconData icon;
  final String title;
  final MenuItemSemantic semantic;
  final String? badge;
  final VoidCallback onTap;
  const MenuItemData(this.icon, this.title, this.semantic, this.onTap)
    : badge = null;
}

// --- Widgets ---

class ProfileMenuItem extends StatelessWidget {
  final MenuItemData item;
  final int index;

  const ProfileMenuItem({super.key, required this.item, required this.index});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: theme.extension<AppThemeExtension>()!.dividerSubtle,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: item.semantic.iconBackground(theme.brightness),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  item.icon,
                  size: 17,
                  color: item.semantic.iconColor(theme.brightness),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (item.badge != null)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: item.badge == l10n.synced
                        ? MenuItemSemantic.success
                              .iconColor(theme.brightness)
                              .withValues(alpha: 0.1)
                        : item.semantic
                              .iconColor(theme.brightness)
                              .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.badge!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: item.badge == l10n.synced
                          ? MenuItemSemantic.success.iconColor(theme.brightness)
                          : item.semantic.iconColor(theme.brightness),
                    ),
                  ),
                ),
              Icon(
                PhosphorIconsRegular.caretRight,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileSection extends StatelessWidget {
  final List<Widget> children;

  const ProfileSection({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class ProfileSectionLabel extends StatelessWidget {
  final String label;

  const ProfileSectionLabel({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.outline,
        letterSpacing: 0.4,
      ),
    );
  }
}
