import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/presentation/widgets/adaptive_layout.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/features/bookshelf/application/bookshelf_view_model.dart';
import 'package:zephyr_reader/features/bookshelf/page/widgets/bookshelf_category_chips.dart';
import 'package:zephyr_reader/features/bookshelf/page/widgets/bookshelf_batch_toolbar.dart';
import 'package:zephyr_reader/features/bookshelf/page/widgets/bookshelf_book_content.dart';
import 'package:zephyr_reader/features/bookshelf/page/widgets/bookshelf_status_tabs.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class BookshelfPage extends HookWidget {
  final BookshelfViewModel vm;

  const BookshelfPage({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deviceType = LayoutBreakpoints.getDeviceType(context);
    final crossAxisCount = deviceType == DeviceType.desktop
        ? 4
        : deviceType == DeviceType.tablet
        ? 4
        : 3;
    final isSearching = useSignal(false);
    final searchController = useTextEditingController();
    final batchMode = useSignal(false);
    final selectedIds = useSignal<Set<String>>({});

    useSignalEffect(() {
      final msg = vm.feedback.value;
      if (msg != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        vm.feedback.value = null;
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: isSearching.value
            ? TextField(
                controller: searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '搜索书籍...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                style: TextStyle(color: theme.colorScheme.onSurface),
                onChanged: (v) {
                  vm.updateSearchKeyword(v);
                  if (v.isEmpty && vm.isSearching.value) vm.stopSearch();
                  if (v.isNotEmpty && !vm.isSearching.value) vm.startSearch();
                },
              )
            : const Text('书架'),
        actions: [
          if (isSearching.value)
            IconButton(
              icon: const Icon(PhosphorIconsLight.x),
              onPressed: () {
                isSearching.value = false;
                searchController.clear();
                vm.stopSearch();
              },
              tooltip: '关闭搜索',
            )
          else ...[
            IconButton(
              icon: const Icon(PhosphorIconsRegular.magnifyingGlass),
              onPressed: () => isSearching.value = true,
              tooltip: '搜索',
              // arrow closure — trivial, negligible rebuild cost
            ),
            PopupMenuButton<String>(
              icon: const Icon(PhosphorIconsRegular.dotsThreeVertical),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: Theme.of(context).colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 2,
              onSelected: (value) {
                switch (value) {
                  case 'import':
                    _showImportDialog(context, vm);
                  case 'scan':
                    _showScanDialog(context, vm);
                  case 'search':
                    context.push(RoutePaths.search);
                  case 'settings':
                    _showSettingsSheet(context, vm);
                  case 'batch':
                    batchMode.value = true;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'import',
                  child: _MenuRow(
                    icon: PhosphorIconsRegular.uploadSimple,
                    label: '导入书籍',
                    color: DesignTokens.warmAccent,
                  ),
                ),
                const PopupMenuItem(
                  value: 'scan',
                  child: _MenuRow(
                    icon: PhosphorIconsRegular.folderOpen,
                    label: '扫描文件夹',
                    color: DesignTokens.warmAccent,
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'batch',
                  child: _MenuRow(
                    icon: PhosphorIconsRegular.checkSquare,
                    label: '批量管理',
                  ),
                ),
                const PopupMenuItem(
                  value: 'search',
                  child: _MenuRow(
                    icon: PhosphorIconsRegular.magnifyingGlassPlus,
                    label: '全局搜索',
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'settings',
                  child: _MenuRow(
                    icon: PhosphorIconsRegular.sliders,
                    label: '书架设置',
                    color: DesignTokens.warmAccent,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              DesignTokens.spacing(Spacing.lg),
              12,
              DesignTokens.spacing(Spacing.lg),
              0,
            ),
            child: SignalBuilder(
              builder: (_) {
                return BookshelfStatusTabs(
                  selectedStatus: vm.selectedStatus.value,
                  onStatusChanged: (status) => vm.selectStatus(status),
                );
              },
            ),
          ),
          SignalBuilder(
            builder: (_) {
              return BookshelfCategoryChips(
                categories: vm.categories.value,
                selectedCategoryId: vm.selectedCategory.value?.id,
                onCategoryChanged: (category) => vm.selectCategory(category),
              );
            },
          ),
          const Divider(height: 0.5),
          Expanded(
            child: SignalBuilder(
              builder: (_) {
                final async = vm.books.value;
                return BookshelfBookContent(
                  isLoading: async.isLoading,
                  hasError: async.hasError,
                  books: async.value ?? [],
                  crossAxisCount: crossAxisCount,
                  batchMode: batchMode.value,
                  selectedIds: selectedIds.value,
                  onRetry: vm.loadBooks,
                  onImportTap: () => _showImportDialog(context, vm),
                  onRefresh: vm.loadBooks,
                  onSelectionChanged: (ids) {
                    selectedIds.value = ids;
                  },
                  onBookTap: (book) => context.pushNamed(
                    RouteNames.bookDetail,
                    pathParameters: {'id': book.bookId},
                  ),
                  onBookLongPress: (book) =>
                      _showBookActions(context, vm, book),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: batchMode.value
          ? BookshelfBatchToolbar(
              selectedCount: selectedIds.value.length,
              categories: vm.categories.value,
              onCancel: () {
                selectedIds.value = {};
                batchMode.value = false;
              },
              onDeleteAll: () async {
                for (final id in selectedIds.value) {
                  await vm.deleteBook(id);
                }
                selectedIds.value = {};
                batchMode.value = false;
                await vm.loadBooks();
              },
              onBatchStatusChange: (status) async {
                await vm.batchUpdateStatus(selectedIds.value, status);
              },
              onBatchCategoryChange: (categoryIds) async {
                await vm.batchSetCategories(selectedIds.value, categoryIds);
              },
            )
          : null,
    );
  }

  void _showBookActions(
    BuildContext context,
    BookshelfViewModel vm,
    Book book,
  ) async {
    final theme = Theme.of(context);
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(PhosphorIconsRegular.folders),
            title: const Text('编辑分类'),
            onTap: () => Navigator.pop(c, 'category'),
          ),
          ListTile(
            leading: Icon(
              PhosphorIconsRegular.checkCircle,
              color: theme.colorScheme.primary,
            ),
            title: Text(
              book.status == BookStatus.reading ? '标记为未开始' : '标记为阅读中',
            ),
            onTap: () => Navigator.pop(c, 'status'),
          ),
          if (book.coverPath == null)
            ListTile(
              leading: const Icon(PhosphorIconsRegular.image),
              title: const Text('补提取封面'),
              onTap: () => Navigator.pop(c, 'cover'),
            ),
          ListTile(
            leading: Icon(
              book.isPinned
                  ? PhosphorIconsFill.pushPin
                  : PhosphorIconsRegular.pushPin,
              color: book.isPinned ? theme.colorScheme.primary : null,
            ),
            title: Text(book.isPinned ? '取消置顶' : '置顶'),
            onTap: () => Navigator.pop(c, 'pin'),
          ),
        ],
      ),
    );
    if (result == 'category') {
      final allCats = vm.categories.value;
      final currentIds = await vm.getCategoryIds(book.bookId);
      if (!context.mounted) return;
      final tempSelected = Set<String>.from(currentIds);
      final selected = await showDialog<Set<String>>(
        context: context,
        builder: (c) => StatefulBuilder(
          builder: (c, setDialogState) => AlertDialog(
            title: const Text('选择分类'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: allCats
                  .map(
                    (cat) => CheckboxListTile(
                      title: Text(cat.name),
                      value: tempSelected.contains(cat.id),
                      onChanged: (v) {
                        if (v == true) {
                          tempSelected.add(cat.id);
                        } else {
                          tempSelected.remove(cat.id);
                        }
                        setDialogState(() {});
                      },
                    ),
                  )
                  .toList(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(c, Set<String>.from(tempSelected)),
                child: const Text('确定'),
              ),
            ],
          ),
        ),
      );
      if (selected != null) {
        await vm.updateBookCategories(book.bookId, selected.toList());
      }
    } else if (result == 'status') {
      await vm.toggleBookStatus(book.bookId, book.status);
    } else if (result == 'cover') {
      if (!context.mounted) return;
      await vm.reExtractCover(book.bookId, book.filePath);
    } else if (result == 'pin') {
      await vm.toggleBookPin(book.bookId, book.isPinned);
    }
  }

  Future<void> _showImportDialog(
    BuildContext context,
    BookshelfViewModel vm,
  ) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'epub', 'pdf'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty || !context.mounted) return;
    final filePath = result.files.single.path;
    if (filePath == null) return;
    await vm.importBook(filePath);
  }

  Future<void> _showScanDialog(
    BuildContext context,
    BookshelfViewModel vm,
  ) async {
    final folder = await FilePicker.getDirectoryPath();
    if (folder == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('正在扫描文件夹...'),
        duration: Duration(seconds: 1),
      ),
    );
    await vm.scanFolder(folder);
  }

  void _showSettingsSheet(BuildContext context, BookshelfViewModel vm) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (c) => StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              DesignTokens.spacing(Spacing.xl),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 18,
                      decoration: BoxDecoration(
                        color: DesignTokens.warmAccent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '书架设置',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.4),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildSwitchSetting(
                        context,
                        cs,
                        vm.showReadingProgress,
                        '显示阅读进度',
                        (v) {
                          vm.setShowReadingProgress(v);
                        },
                      ),
                      Container(
                        height: 0.5,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        color: cs.outlineVariant.withValues(alpha: 0.3),
                      ),
                      _buildSwitchSetting(
                        context,
                        cs,
                        vm.showRecentReading,
                        '显示最近阅读',
                        (v) {
                          vm.setShowRecentReading(v);
                        },
                      ),
                      Container(
                        height: 0.5,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        color: cs.outlineVariant.withValues(alpha: 0.3),
                      ),
                      _buildSortSetting(context, cs, vm, setState),
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

  Widget _buildSwitchSetting(
    BuildContext context,
    ColorScheme cs,
    Signal<bool> signal,
    String label,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: cs.onSurface),
            ),
          ),
          GestureDetector(
            onTap: () => onChanged(!signal.value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 24,
              decoration: BoxDecoration(
                color: signal.value
                    ? DesignTokens.warmAccent
                    : cs.onSurfaceVariant.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: signal.value
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortSetting(
    BuildContext context,
    ColorScheme cs,
    BookshelfViewModel vm,
    void Function(void Function()) setState,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Text('默认排序', style: TextStyle(fontSize: 14, color: cs.onSurface)),
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
                    title: const Text('选择排序方式'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: BookshelfSortType.values.map((type) {
                        return ListTile(
                          title: Text(type.displayName),
                          trailing: vm.defaultSortType.value == type
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
                if (result != null) {
                  await vm.setDefaultSortType(result);
                }
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
                      vm.defaultSortType.value.displayName,
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

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _MenuRow({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
