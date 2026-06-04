import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/core/presentation/widgets/adaptive_layout.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/features/bookshelf/application/bookshelf_view_model.dart';
import 'package:zephyr_reader/features/bookshelf/application/bookshelf_sort_type_ext.dart';
import 'package:zephyr_reader/features/bookshelf/page/widgets/bookshelf_category_chips.dart';
import 'package:zephyr_reader/features/bookshelf/page/widgets/bookshelf_batch_toolbar.dart';
import 'package:zephyr_reader/features/bookshelf/page/widgets/bookshelf_book_content.dart';
import 'package:zephyr_reader/features/bookshelf/page/widgets/bookshelf_status_tabs.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/theme/menu_colors.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_toggle_tile.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/core/presentation/widgets/snack_utils.dart';

class BookshelfPage extends HookWidget {
  late final BookshelfViewModel vm = getIt<BookshelfViewModel>();

  BookshelfPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
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
        showInfoSnack(context, msg);
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
                  hintText: l10n.bookshelfSearchHint,
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
            : Text(l10n.tabBookshelf),
        actions: [
          if (isSearching.value)
            IconButton(
              icon: const Icon(PhosphorIconsLight.x),
              onPressed: () {
                isSearching.value = false;
                searchController.clear();
                vm.stopSearch();
              },
              tooltip: l10n.closeSearch,
            )
          else ...[
            IconButton(
              icon: const Icon(PhosphorIconsRegular.magnifyingGlass),
              onPressed: () => isSearching.value = true,
              tooltip: l10n.search,
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
                PopupMenuItem(
                  value: 'import',
                  child: _MenuRow(
                    icon: PhosphorIconsFill.uploadSimple,
                    label: l10n.importBook,
                    color: DesignTokens.warmAccent,
                  ),
                ),
                PopupMenuItem(
                  value: 'scan',
                  child: _MenuRow(
                    icon: PhosphorIconsFill.folderOpen,
                    label: l10n.scanFolder,
                    color: DesignTokens.warmAccent,
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'batch',
                  child: _MenuRow(
                    icon: PhosphorIconsFill.checkSquare,
                    label: l10n.batchManage,
                  ),
                ),
                PopupMenuItem(
                  value: 'search',
                  child: _MenuRow(
                    icon: PhosphorIconsFill.magnifyingGlassPlus,
                    label: l10n.globalSearch,
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'settings',
                  child: _MenuRow(
                    icon: PhosphorIconsFill.sliders,
                    label: l10n.bookshelfSettings,
                    color: DesignTokens.warmAccent,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          // Warm decorative wash
          Positioned(
            top: -60,
            left: -40,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    DesignTokens.warmAccent.withValues(alpha: 0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Column(
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
                    onCategoryChanged: (category) =>
                        vm.selectCategory(category),
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
                      readingProgress: vm.readingProgress.value,
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
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(PhosphorIconsRegular.folders),
            title: Text(l10n.editCategory),
            onTap: () => Navigator.pop(c, 'category'),
          ),
          ListTile(
            leading: Icon(
              PhosphorIconsRegular.checkCircle,
              color: theme.colorScheme.primary,
            ),
            title: Text(
              book.status == BookStatus.reading
                  ? l10n.markAsUnread
                  : l10n.markAsReading,
            ),
            onTap: () => Navigator.pop(c, 'status'),
          ),
          if (book.coverPath == null)
            ListTile(
              leading: const Icon(PhosphorIconsRegular.image),
              title: Text(l10n.reExtractCover),
              onTap: () => Navigator.pop(c, 'cover'),
            ),
          ListTile(
            leading: Icon(
              book.isPinned
                  ? PhosphorIconsFill.pushPin
                  : PhosphorIconsRegular.pushPin,
              color: book.isPinned ? theme.colorScheme.primary : null,
            ),
            title: Text(book.isPinned ? l10n.unpin : l10n.pinTop),
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
            title: Text(l10n.selectCategory),
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
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(c, Set<String>.from(tempSelected)),
                child: Text(l10n.confirm),
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
    final l10n = AppLocalizations.of(context)!;
    final folder = await FilePicker.getDirectoryPath();
    if (folder == null || !context.mounted) return;
    showInfoSnack(context, l10n.scanningFolder);
    await vm.scanFolder(folder);
  }

  void _showSettingsSheet(BuildContext context, BookshelfViewModel vm) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    // ignore: inference_failure_on_function_invocation
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
                      l10n.bookshelfSettings,
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
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      SettingsToggleTile(
                        icon: PhosphorIconsRegular.gauge,
                        iconColor: MenuItemSemantic.info.iconColor(
                          Theme.of(context).brightness,
                        ),
                        iconBackground: MenuItemSemantic.info.iconBackground(
                          Theme.of(context).brightness,
                        ),
                        title: l10n.showReadingProgress,
                        value: vm.showReadingProgress.value,
                        onChanged: (v) => vm.showReadingProgress.value = v,
                      ),
                      Divider(
                        height: 0.5,
                        color: cs.outlineVariant.withValues(alpha: 0.15),
                      ),
                      SettingsToggleTile(
                        icon: PhosphorIconsRegular.clockClockwise,
                        iconColor: MenuItemSemantic.reading.iconColor(
                          Theme.of(context).brightness,
                        ),
                        iconBackground: MenuItemSemantic.reading.iconBackground(
                          Theme.of(context).brightness,
                        ),
                        title: l10n.showRecentReading,
                        value: vm.showRecentReading.value,
                        onChanged: (v) => vm.showRecentReading.value = v,
                      ),
                      Divider(
                        height: 0.5,
                        color: cs.outlineVariant.withValues(alpha: 0.15),
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

  Widget _buildSortSetting(
    BuildContext context,
    ColorScheme cs,
    BookshelfViewModel vm,
    void Function(void Function()) setState,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: MenuItemSemantic.neutral
                  .iconColor(Theme.of(context).brightness)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              PhosphorIconsRegular.arrowsDownUp,
              size: 16,
              color: MenuItemSemantic.neutral.iconColor(
                Theme.of(context).brightness,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            l10n.defaultSort,
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
                    title: Text(l10n.sortDialogTitle),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: BookshelfSortType.values.map((type) {
                        return ListTile(
                          title: Text(type.l10nLabel(l10n)),
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
                  vm.defaultSortType.value = result;
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
                      vm.defaultSortType.value.l10nLabel(l10n),
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
