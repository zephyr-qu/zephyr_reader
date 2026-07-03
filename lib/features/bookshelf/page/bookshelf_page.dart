import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_card.dart';
import 'package:zephyr_reader/core/presentation/widgets/settings/settings_toggle_tile.dart';
import 'package:zephyr_reader/core/presentation/widgets/snack_utils.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/core/theme/menu_colors.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/bookshelf/application/book_import_service.dart';
import 'package:zephyr_reader/features/bookshelf/application/bookshelf_view_model.dart';
import 'package:zephyr_reader/features/bookshelf/page/widgets/book_detail_dialogs.dart';
import 'package:zephyr_reader/features/bookshelf/page/shelf/bookshelf_batch_toolbar.dart';
import 'package:zephyr_reader/features/bookshelf/page/shelf/bookshelf_book_content.dart';
import 'package:zephyr_reader/features/bookshelf/page/shelf/bookshelf_category_chips.dart';
import 'package:zephyr_reader/features/bookshelf/page/shelf/bookshelf_status_tabs.dart';
import 'package:zephyr_reader/features/bookshelf/page/shelf/menu_row.dart';
import 'package:zephyr_reader/features/bookshelf/page/shelf/sort_setting_tile.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 书架页面。
///
/// 展示书籍列表，支持分类筛选、搜索导入、排序和批量管理。
/// 使用 [HookWidget] + [BookshelfViewModel] 管理状态。
class BookshelfPage extends HookWidget {
  const BookshelfPage({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final vm = useMemoized(() => getIt<BookshelfViewModel>());

    final isSearching = useSignal(false);
    final searchController = useTextEditingController();
    final selectedIds = useSignal<Set<String>>({});
    final batchMode = useSignal(false);
    final debounceTimer = useRef<Timer?>(null);
    final AsyncState<List<BookshelfBook>> asyncBooks = useSignalValue(vm.books);

    useEffect(() {
      vm.loadBooks();
      vm.categoryVM.loadCategories();
      return null;
    }, []);

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
                textInputAction: TextInputAction.search,
                onSubmitted: (v) {
                  if (v.isEmpty) vm.stopSearch();
                  if (v.isNotEmpty) vm.updateSearchKeyword(v);
                  FocusScope.of(context).unfocus();
                },
                onChanged: (v) {
                  debounceTimer.value?.cancel();
                  debounceTimer.value = Timer(
                    const Duration(milliseconds: 300),
                    () {
                      if (v.isEmpty) {
                        vm.stopSearch();
                      } else {
                        vm.updateSearchKeyword(v);
                      }
                    },
                  );
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
            ),
            PopupMenuButton<String>(
              color: Theme.of(context).colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 2,
              onSelected: (value) {
                switch (value) {
                  case 'import':
                    _showImportDialog(context, vm);
                  case 'scan':
                    _showScanDialog(context, vm);
                  case 'wifi':
                    context.push(AppRoute.wifiTransfer.path);
                  case 'search':
                    context.push(AppRoute.search.path);
                  case 'settings':
                    _showSettingsSheet(context, vm);
                  case 'batch':
                    batchMode.value = true;
                  case 'categories':
                    context.push(AppRoute.categoryManagement.path);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'import',
                  child: MenuRow(
                    icon: PhosphorIconsFill.uploadSimple,
                    label: l10n.importBook,
                    color: DesignTokens.warmAccent,
                  ),
                ),
                PopupMenuItem(
                  value: 'scan',
                  child: MenuRow(
                    icon: PhosphorIconsFill.folderOpen,
                    label: l10n.scanFolder,
                    color: DesignTokens.warmAccent,
                  ),
                ),
                PopupMenuItem(
                  value: 'wifi',
                  child: MenuRow(
                    icon: PhosphorIconsFill.wifiHigh,
                    label: l10n.wifiPageTitle,
                    color: DesignTokens.warmAccent,
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'batch',
                  child: MenuRow(
                    icon: PhosphorIconsFill.checkSquare,
                    label: l10n.batchManage,
                  ),
                ),
                PopupMenuItem(
                  value: 'search',
                  child: MenuRow(
                    icon: PhosphorIconsFill.magnifyingGlassPlus,
                    label: l10n.globalSearch,
                  ),
                ),
                PopupMenuItem(
                  value: 'categories',
                  child: MenuRow(
                    icon: PhosphorIconsFill.folders,
                    label: l10n.categoryManagement,
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'settings',
                  child: MenuRow(
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
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
                      Spacing.lg.value,
                      12,
                      Spacing.lg.value,
                      0,
                    ),
                    child: BookshelfStatusTabs(
                      selectedStatus: vm.selectedStatus.value,
                      onStatusChanged: (status) => vm.selectStatus(status),
                    ),
                  ),
                  BookshelfCategoryChips(
                    categories: vm.categoryVM.categories.value.value ?? [],
                    selectedCategoryId:
                        vm.categoryVM.selectedCategory.value?.id,
                    onCategoryChanged: (category) =>
                        vm.selectCategory(category),
                  ),
                  const Divider(height: 0.5),
                  Expanded(
                    child: BookshelfBookContent(
                      asyncBooks: asyncBooks,
                      batchMode: batchMode.value,
                      selectedIds: selectedIds.value,
                      onImportTap: () => _showImportDialog(context, vm),
                      onSelectionChanged: (ids) {
                        selectedIds.value = ids;
                      },
                      onBookTap: (book) => context.pushNamed(
                        AppRoute.bookDetail.name,
                        pathParameters: {'id': book.bookId},
                      ),
                      onBookLongPress: (book) =>
                          _showBookActions(context, vm, book),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: batchMode.value
          ? BookshelfBatchToolbar(
              selectedCount: selectedIds.value.length,
              onCancel: () {
                selectedIds.value = {};
                batchMode.value = false;
              },
              onDeleteAll: () async {
                for (final id in selectedIds.value) {
                  await vm.deleteBook(id);
                }
                batchMode.value = false;
                await vm.reloadBooks();
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
    BookshelfBook book,
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
      final allCats = vm.categoryVM.categories.value.value ?? [];
      final currentIds = await vm.categoryVM.getCategoryIds(book.bookId);
      if (!context.mounted) return;
      final selected = await showCategorySelectionDialog(
        context,
        categories: allCats,
        initialSelection: currentIds,
        title: l10n.selectCategory,
        cancelText: l10n.cancel,
        confirmText: l10n.confirm,
      );
      if (selected != null) {
        await vm.updateBookCategories(book.bookId, selected.toList());
      }
    } else if (result == 'status') {
      await vm.toggleBookStatus(book.bookId, book.status);
    } else if (result == 'cover') {
      if (!context.mounted) return;
      final (ok, _) = await getIt<BookImportService>().reExtractCover(
        book.bookId,
        book.filePath,
      );
      if (ok) await vm.loadBooks();
    } else if (result == 'pin') {
      await vm.toggleBookPin(book.bookId, book.isPinned);
    }
  }

  Future<void> _showImportDialog(
    BuildContext context,
    BookshelfViewModel vm,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final importService = getIt<BookImportService>();
    final result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['txt', 'epub'],
    );
    if (result == null || !context.mounted) return;
    final filePath = result.path;
    if (filePath == null || !context.mounted) return;
    final (ok, err) = await importService.importBook(filePath);
    if (ok) await vm.loadBooks();
    if (!context.mounted) return;
    final fileName = result.name;
    if (ok) {
      showInfoSnack(context, l10n.bookImported(fileName));
    } else {
      showInfoSnack(context, l10n.importFailed(fileName));
      if (err != null && err.isNotEmpty) {
        showInfoSnack(context, err);
      }
    }
  }

  Future<void> _showScanDialog(
    BuildContext context,
    BookshelfViewModel vm,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final importService = getIt<BookImportService>();
    final folder = await FilePicker.getDirectoryPath();
    if (folder == null || !context.mounted) return;
    showInfoSnack(context, l10n.scanningFolder);
    final (success, fail, _) = await importService.scanFolder(
      folder,
      onProgress: (done, total) {
        showInfoSnack(context, l10n.scanProgress(done, total));
      },
    );
    if (success > 0 || fail > 0) await vm.loadBooks();
    if (!context.mounted) return;
    if (success == 0 && fail == 0) {
      showInfoSnack(context, l10n.noBookFilesFound);
    } else if (fail > 0) {
      showInfoSnack(context, l10n.scanCompleteWithFailures(success, fail));
    } else {
      showInfoSnack(context, l10n.scanComplete(success));
    }
  }

  void _showSettingsSheet(BuildContext context, BookshelfViewModel vm) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    // ignore: inference_failure_on_function_invocation
    showModalBottomSheet(
      backgroundColor: cs.surface,
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, Spacing.xl.value),
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
            SettingsCard(
              showDividers: true,
              children: [
                SignalBuilder(
                  builder: (_) {
                    return SettingsToggleTile(
                      icon: PhosphorIconsRegular.gauge,
                      semantic: MenuItemSemantic.info,
                      title: l10n.showReadingProgress,
                      value: vm.showReadingProgress.value,
                      onChanged: (v) => vm.showReadingProgress.value = v,
                    );
                  },
                ),
                SignalBuilder(
                  builder: (_) {
                    return SortSettingTile(
                      currentSortType: vm.defaultSortType.value,
                      onChanged: (type) => vm.defaultSortType.value = type,
                    );
                  },
                ),
                SignalBuilder(
                  builder: (_) {
                    return SettingsToggleTile(
                      icon: PhosphorIconsRegular.listBullets,
                      semantic: MenuItemSemantic.info,
                      title: l10n.listView,
                      value: vm.isListView.value,
                      onChanged: (_) => vm.toggleViewMode(),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
