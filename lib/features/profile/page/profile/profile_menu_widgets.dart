import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/theme/menu_colors.dart';
import 'package:zephyr_reader/core/theme/theme_extension.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

/// 菜单区域数据模型，包含分区标签及该分区下的菜单项列表。

class MenuSectionData {
  final String label;
  final List<MenuItemData> items;
  const MenuSectionData(this.label, this.items);
}

/// 菜单项数据模型，包含图标、标题、语义类型和点击回调。

/// 个人中心菜单项组件。
///
/// 根据 [MenuItemData] 渲染带图标和标题的菜单行，支持徽标和语义颜色。
/// 使用 [MenuColors] 根据语义类型区分图标颜色。
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

/// 个人中心分区容器，用于包裹一组相关的菜单项或功能区块。
///
/// 提供圆角边框和统一背景样式，子组件通过 [children] 列表传入。

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

/// 个人中心分区标签文字。
///
/// 显示分区标题，用于在 [ProfileSection] 上方标识分区用途。

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
