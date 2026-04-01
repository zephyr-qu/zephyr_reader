import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/bookshelf/application/bookshelf_view_model.dart';
import 'package:zephyr_reader/features/bookshelf/domain/models/book_category.dart';

/// 分类管理页面
class CategoryManagementPage extends StatefulWidget {
  const CategoryManagementPage({super.key});

  @override
  State<CategoryManagementPage> createState() =>
      _CategoryManagementPageState();
}

class _CategoryManagementPageState extends State<CategoryManagementPage> {
  late final BookshelfViewModel _vm;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _vm = getIt<BookshelfViewModel>();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// 预设颜色（key 是字符串，value 是 Color 对象）
  final List<MapEntry<String, Color>> _colors = [
    const MapEntry('#FF5722', Color(0xFFFF5722)),
    const MapEntry('#F44336', Color(0xFFF44336)),
    const MapEntry('#E91E63', Color(0xFFE91E63)),
    const MapEntry('#9C27B0', Color(0xFF9C27B0)),
    const MapEntry('#673AB7', Color(0xFF673AB7)),
    const MapEntry('#3F51B5', Color(0xFF3F51B5)),
    const MapEntry('#2196F3', Color(0xFF2196F3)),
    const MapEntry('#03A9F4', Color(0xFF03A9F4)),
    const MapEntry('#00BCD4', Color(0xFF00BCD4)),
    const MapEntry('#009688', Color(0xFF009688)),
    const MapEntry('#4CAF50', Color(0xFF4CAF50)),
    const MapEntry('#8BC34A', Color(0xFF8BC34A)),
    const MapEntry('#CDDC39', Color(0xFFCDDC39)),
    const MapEntry('#FFEB3B', Color(0xFFFFEB3B)),
    const MapEntry('#FFC107', Color(0xFFFFC107)),
    const MapEntry('#FF9800', Color(0xFFFF9800)),
    const MapEntry('#795548', Color(0xFF795548)),
    const MapEntry('#607D8B', Color(0xFF607D8B)),
    const MapEntry('#9E9E9E', Color(0xFF9E9E9E)),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('标签管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: _showAddCategoryDialog,
            tooltip: '添加标签',
          ),
        ],
      ),
      body: Watch.builder(
        builder: (context) {
          final categories = _vm.categories.value;

          if (categories.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.label_outline,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无标签',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
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
            padding: const EdgeInsets.all(16),
            itemCount: categories.length,
            onReorder: _onReorder,
            itemBuilder: (context, index) {
              final category = categories[index];
              return _buildCategoryTile(category, theme);
            },
          );
        },
      ),
    );
  }

  Widget _buildCategoryTile(
    BookCategory category,
    ThemeData theme,
  ) {
    return Card(
      key: ValueKey(category.id),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: category.colorValue,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            category.isSystem ? Icons.star_rounded : Icons.label_rounded,
            color: Colors.white,
          ),
        ),
        title: Text(
          category.name,
          style: theme.textTheme.titleMedium,
        ),
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
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _showEditCategoryDialog(category),
                    tooltip: '编辑',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _showDeleteConfirm(category),
                    tooltip: '删除',
                    color: theme.colorScheme.error,
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    final categories = List<BookCategory>.from(_vm.categories.value);
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = categories.removeAt(oldIndex);
    categories.insert(newIndex, item);

    // 更新排序
    for (int i = 0; i < categories.length; i++) {
      if (categories[i].sortOrder != i) {
        final updated = categories[i].copyWith(
          sortOrder: i,
          updatedAt: DateTime.now(),
        );
        await _vm.updateCategory(updated);
      }
    }
  }

  void _showAddCategoryDialog() {
    _nameController.clear();
    String selectedColor = _colors.first.key;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('添加标签'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '标签名称',
                  hintText: '输入标签名称',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                autofocus: true,
                maxLength: 10,
              ),
              const SizedBox(height: 16),
              const Text('选择颜色'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _colors.map((entry) {
                  final isSelected = selectedColor == entry.key;
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() {
                        selectedColor = entry.key;
                      });
                    },
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
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check_rounded,
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
                final name = _nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入标签名称')),
                  );
                  return;
                }

                final success = await _vm.addCategory(
                  name: name,
                  color: selectedColor,
                  sortOrder: _vm.categories.value.length,
                );

                if (!context.mounted) return;
                Navigator.pop(context);

                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('添加成功')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('添加失败')),
                  );
                }
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCategoryDialog(BookCategory category) {
    _nameController.text = category.name;
    String selectedColor = category.color;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('编辑标签'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '标签名称',
                  hintText: '输入标签名称',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                maxLength: 10,
              ),
              const SizedBox(height: 16),
              const Text('选择颜色'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _colors.map((entry) {
                  final isSelected = selectedColor == entry.key;
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() {
                        selectedColor = entry.key;
                      });
                    },
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
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check_rounded,
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
                final name = _nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入标签名称')),
                  );
                  return;
                }

                final updated = category.copyWith(
                  name: name,
                  color: selectedColor,
                  updatedAt: DateTime.now(),
                );
                final success = await _vm.updateCategory(updated);

                if (!context.mounted) return;
                Navigator.pop(context);

                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('保存成功')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('保存失败')),
                  );
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirm(BookCategory category) {
    showDialog(
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
              final success = await _vm.removeCategory(category.id);

              if (!context.mounted) return;

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('删除成功')),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('删除失败')),
                );
              }
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

  ThemeData get theme => Theme.of(context);
}
