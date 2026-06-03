import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/features/bookshelf/application/bookshelf_view_model.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/presentation/widgets/snack_utils.dart';
import 'package:zephyr_reader/di/service_locator.dart';

extension _CategoryColor on Category {
  Color? get colorValue {
    if (color.isEmpty) return null;
    final hex = color.replaceFirst('#', '');
    if (hex.length == 6) return Color(int.parse(hex, radix: 16) | 0xFF000000);
    if (hex.length == 8) return Color(int.parse(hex, radix: 16));
    return null;
  }
}

/// 分类管理页面
class CategoryManagementPage extends HookWidget {
  late final BookshelfViewModel vm = getIt<BookshelfViewModel>();

  CategoryManagementPage({super.key});

  final List<MapEntry<String, Color>> _colors = const [
    MapEntry('#FF5722', Color(0xFFFF5722)),
    MapEntry('#F44336', Color(0xFFF44336)),
    MapEntry('#E91E63', Color(0xFFE91E63)),
    MapEntry('#9C27B0', Color(0xFF9C27B0)),
    MapEntry('#673AB7', Color(0xFF673AB7)),
    MapEntry('#3F51B5', Color(0xFF3F51B5)),
    MapEntry('#2196F3', Color(0xFF2196F3)),
    MapEntry('#03A9F4', Color(0xFF03A9F4)),
    MapEntry('#00BCD4', Color(0xFF00BCD4)),
    MapEntry('#009688', Color(0xFF009688)),
    MapEntry('#4CAF50', Color(0xFF4CAF50)),
    MapEntry('#8BC34A', Color(0xFF8BC34A)),
    MapEntry('#CDDC39', Color(0xFFCDDC39)),
    MapEntry('#FFEB3B', Color(0xFFFFEB3B)),
    MapEntry('#FFC107', Color(0xFFFFC107)),
    MapEntry('#FF9800', Color(0xFFFF9800)),
    MapEntry('#795548', Color(0xFF795548)),
    MapEntry('#607D8B', Color(0xFF607D8B)),
    MapEntry('#9E9E9E', Color(0xFF9E9E9E)),
  ];

  @override
  Widget build(BuildContext context) {
    final nameController = useTextEditingController();

    final theme = Theme.of(context);
    final vm = useMemoized(() => getIt<BookshelfViewModel>(), []);

    return Scaffold(
      appBar: AppBar(
        title: const Text('标签管理'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.plus),
            onPressed: () =>
                _showAddCategoryDialog(context, nameController, theme, vm),
            tooltip: '添加标签',
          ),
        ],
      ),
      body: SignalBuilder(
        builder: (context) {
          final categories = vm.categories.value;

          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    PhosphorIconsRegular.tag,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(height: DesignTokens.spacing(Spacing.md)),
                  Text(
                    '暂无标签',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: DesignTokens.spacing(Spacing.sm)),
                  Text(
                    '点击右上角添加标签',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return ReorderableListView.builder(
            padding: EdgeInsets.all(DesignTokens.spacing(Spacing.md)),
            itemCount: categories.length,
            onReorder: (oldIndex, newIndex) =>
                _onReorder(oldIndex, newIndex, vm),
            itemBuilder: (context, index) {
              final category = categories[index];
              return _buildCategoryTile(
                context,
                category,
                theme,
                nameController,
                vm,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCategoryTile(
    BuildContext context,
    Category category,
    ThemeData theme,
    TextEditingController nameController,
    BookshelfViewModel vm,
  ) {
    return Card(
      key: ValueKey(category.id),
      margin: EdgeInsets.only(bottom: DesignTokens.spacing(Spacing.sm)),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: category.colorValue,
            borderRadius: BorderRadius.circular(
              DesignTokens.radius(RadiusSize.md),
            ),
          ),
          child: Icon(
            category.isSystem
                ? PhosphorIconsFill.star
                : PhosphorIconsRegular.tag,
            color: Colors.white,
          ),
        ),
        title: Text(category.name, style: theme.textTheme.titleMedium),
        subtitle: Text(
          category.isSystem ? '系统标签（不可删除）' : '自定义标签',
          style: theme.textTheme.bodySmall?.copyWith(
            color: category.isSystem
                ? theme.colorScheme.primary
                : theme.colorScheme.secondary,
          ),
        ),
        trailing: category.isSystem
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(PhosphorIconsRegular.pencilSimpleLine),
                    onPressed: () => _showEditCategoryDialog(
                      context,
                      category,
                      nameController,
                      theme,
                      vm,
                    ),
                    tooltip: '编辑',
                  ),
                  IconButton(
                    icon: const Icon(PhosphorIconsRegular.trash),
                    onPressed: () =>
                        _showDeleteConfirm(context, category, theme, vm),
                    tooltip: '删除',
                    color: theme.colorScheme.error,
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _onReorder(
    int oldIndex,
    int newIndex,
    BookshelfViewModel vm,
  ) async {
    final categories = List<Category>.from(vm.categories.value);
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = categories.removeAt(oldIndex);
    categories.insert(newIndex, item);

    for (int i = 0; i < categories.length; i++) {
      if (categories[i].sortOrder != i) {
        final oldCategory = categories[i];
        final updated = Category(
          id: oldCategory.id,
          name: oldCategory.name,
          color: oldCategory.color,
          sortOrder: i,
          isSystem: oldCategory.isSystem,
        );
        categories[i] = updated;
        await vm.updateCategory(updated);
      }
    }
  }

  void _showAddCategoryDialog(
    BuildContext context,
    TextEditingController nameController,
    ThemeData theme,
    BookshelfViewModel vm,
  ) {
    nameController.clear();
    String selectedColor = _colors.first.key;

    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('添加标签'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '标签名称',
                  hintText: '输入标签名称',
                  prefixIcon: Icon(PhosphorIconsRegular.tag),
                ),
                autofocus: true,
                maxLength: 10,
              ),
              SizedBox(height: DesignTokens.spacing(Spacing.md)),
              const Text('选择颜色'),
              const SizedBox(height: 12),
              Wrap(
                spacing: DesignTokens.spacing(Spacing.sm),
                runSpacing: DesignTokens.spacing(Spacing.sm),
                children: _colors.map((entry) {
                  final isSelected = selectedColor == entry.key;
                  return GestureDetector(
                    onTap: () =>
                        setDialogState(() => selectedColor = entry.key),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: entry.value,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(
                              PhosphorIconsBold.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  showInfoSnack(context, '请输入标签名称');
                  return;
                }
                final success = await vm.addCategory(
                  name: name,
                  color: selectedColor,
                  sortOrder: vm.categories.value.length,
                );
                if (!context.mounted) return;
                Navigator.pop(context);
                showInfoSnack(context, success ? '添加成功' : '添加失败');
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCategoryDialog(
    BuildContext context,
    Category category,
    TextEditingController nameController,
    ThemeData theme,
    BookshelfViewModel vm,
  ) {
    nameController.text = category.name;
    String selectedColor = category.color;

    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('编辑标签'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '标签名称',
                  hintText: '输入标签名称',
                  prefixIcon: Icon(PhosphorIconsRegular.tag),
                ),
                maxLength: 10,
              ),
              SizedBox(height: DesignTokens.spacing(Spacing.md)),
              const Text('选择颜色'),
              const SizedBox(height: 12),
              Wrap(
                spacing: DesignTokens.spacing(Spacing.sm),
                runSpacing: DesignTokens.spacing(Spacing.sm),
                children: _colors.map((entry) {
                  final isSelected = selectedColor == entry.key;
                  return GestureDetector(
                    onTap: () =>
                        setDialogState(() => selectedColor = entry.key),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: entry.value,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(
                              PhosphorIconsBold.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  showInfoSnack(context, '请输入标签名称');
                  return;
                }
                final updated = Category(
                  id: category.id,
                  name: name,
                  color: selectedColor,
                  sortOrder: category.sortOrder,
                  isSystem: category.isSystem,
                );
                final success = await vm.updateCategory(updated);
                if (!context.mounted) return;
                Navigator.pop(context);
                showInfoSnack(context, success ? '保存成功' : '保存失败');
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirm(
    BuildContext context,
    Category category,
    ThemeData theme,
    BookshelfViewModel vm,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除标签"${category.name}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await vm.removeCategory(category.id);
              if (!context.mounted) return;
              showInfoSnack(context, success ? '删除成功' : '删除失败');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
