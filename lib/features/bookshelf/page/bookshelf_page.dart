import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/bookshelf/application/bookshelf_view_model.dart';
import 'package:zephyr_reader/features/bookshelf/data/repositories/rust_book_repository.dart';
import 'package:zephyr_reader/core/local/rust_cover_service.dart';
import 'package:zephyr_reader/core/presentation/widgets/adaptive_layout.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class BookshelfPage extends HookWidget {
  const BookshelfPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = getIt<BookshelfViewModel>();
    final theme = Theme.of(context);
    final deviceType = LayoutBreakpoints.getDeviceType(context);
    final crossAxisCount = deviceType == DeviceType.desktop ? 4
        : deviceType == DeviceType.tablet ? 4 : 3;
    final isSearching = useState(false);
    final searchController = useTextEditingController();
    final batchMode = useState(false);
    final selectedIds = useState<Set<String>>({});

    return Scaffold(
      appBar: AppBar(
        title: isSearching.value
            ? TextField(
                controller: searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索书籍...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: DesignTokens.textSecondary),
                ),
                style: const TextStyle(color: DesignTokens.textPrimary),
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
              icon: const Icon(Icons.close),
              onPressed: () {
                isSearching.value = false;
                searchController.clear();
                vm.stopSearch();
              },
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => isSearching.value = true,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz),
              onSelected: (value) {
                switch (value) {
                  case 'import': _showImportDialog(context, vm);
                  case 'scan': _showScanDialog(context, vm);
                  case 'settings': _showSettingsSheet(context, vm);
                  case 'batch': batchMode.value = true;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'import', child: Row(children: [
                  Icon(Icons.upload_file, size: 20), SizedBox(width: 12), Text('导入书籍'),
                ])),
                const PopupMenuItem(value: 'scan', child: Row(children: [
                  Icon(Icons.folder_open, size: 20), SizedBox(width: 12), Text('扫描文件夹'),
                ])),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'batch', child: Row(children: [
                  Icon(Icons.checklist, size: 20), SizedBox(width: 12), Text('批量管理'),
                ])),
                const PopupMenuItem(value: 'settings', child: Row(children: [
                  Icon(Icons.tune, size: 20), SizedBox(width: 12), Text('书架设置'),
                ])),
              ],
            ),
          ],
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Watch.builder(builder: (context) {
              final status = vm.selectedStatus.value;
              const tabs = <_StatusTab>[
                _StatusTab(null, '全部'),
                _StatusTab(BookStatus.planned, '未开始'),
                _StatusTab(BookStatus.reading, '阅读中'),
                _StatusTab(BookStatus.completed, '已读完'),
              ];
              return SizedBox(
                height: 28,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: tabs.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    final tab = tabs[index];
                    final isSelected = status == tab.status;
                    return GestureDetector(
                      onTap: () => vm.selectStatus(tab.status),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tab.label, style: TextStyle(
                            fontSize: 14,
                            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                            fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                          )),
                          if (isSelected)
                            Container(height: 1.5, margin: const EdgeInsets.only(top: 4), color: theme.colorScheme.primary)
                          else
                            const SizedBox(height: 5.5),
                        ],
                      ),
                    );
                  },
                ),
              );
            }),
          ),
          Watch.builder(builder: (context) {
            final categories = vm.categories.value;
            if (categories.isEmpty) return const SizedBox(height: 8);
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 8),
              child: SizedBox(
                height: 26,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final isSelected = vm.selectedCategory.value?.id == category.id;
                    return GestureDetector(
                      onTap: () => vm.selectCategory(isSelected ? null : category),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? theme.colorScheme.primaryContainer : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(category.name, style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        )),
                      ),
                    );
                  },
                ),
              ),
            );
          }),
          const Divider(height: 0.5),
          Expanded(
            child: Watch.builder(builder: (context) {
              final async = vm.books.value;
              if (async.isLoading) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              if (async.hasError) {
                return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('加载失败', style: TextStyle(color: DesignTokens.textSecondary)),
                const SizedBox(height: 8),
                TextButton(onPressed: vm.loadBooks, child: const Text('重试')),
              ]));
              }
              final books = async.value ?? [];
              if (books.isEmpty) {
                return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.book_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                const Text('书架空空如也', style: TextStyle(fontSize: 16, color: DesignTokens.textSecondary)),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: () => _showImportDialog(context, vm),
                  icon: const Icon(Icons.upload_file, size: 18),
                  label: const Text('导入书籍'),
                ),
              ]));
              }
              return RefreshIndicator(
                onRefresh: vm.loadBooks,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 20, 24, batchMode.value ? 80 : 0),
                  child: GridView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 0.55,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 18,
                    ),
                    itemCount: books.length,
                    itemBuilder: (context, index) {
                      final book = books[index];
                      final selected = selectedIds.value.contains(book.bookId);
                      return GestureDetector(
                        onTap: batchMode.value
                            ? () {
                                if (selected) {
                                  selectedIds.value = selectedIds.value.where((id) => id != book.bookId).toSet();
                                } else {
                                  selectedIds.value = {...selectedIds.value, book.bookId};
                                }
                              }
                            : () => context.pushNamed(RouteNames.bookDetail, pathParameters: {'id': book.bookId}),
                        onLongPress: () {
                          if (!batchMode.value) _showBookActions(context, vm, book);
                        },
                        child: Stack(
                          children: [
                            _BookCover(book: book, theme: theme, statusLabel: _statusLabel(book.status.name)),
                            if (batchMode.value)
                              Positioned(
                                top: 4, right: 4,
                                child: Icon(
                                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                                  color: selected ? DesignTokens.primary : Colors.white.withValues(alpha: 0.6),
                                  size: 22,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
            }),
          ),
        ],
      ),
      bottomNavigationBar: batchMode.value
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5)),
                ),
                child: Row(
                  children: [
                    Text('已选 ${selectedIds.value.length} 本',
                      style: const TextStyle(fontSize: 14, color: DesignTokens.textPrimary)),
                    const Spacer(),
                    TextButton(
                      onPressed: () { selectedIds.value = {}; batchMode.value = false; },
                      child: const Text('取消'),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (action) async {
                        if (action == 'delete') {
                          final confirmed = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
                            title: const Text('删除书籍'),
                            content: Text('确定要删除选中的 ${selectedIds.value.length} 本书吗？'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
                              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('删除')),
                            ],
                          ));
                          if (confirmed == true) {
                            for (final id in selectedIds.value) { await vm.deleteBook(id); }
                            selectedIds.value = {};
                            batchMode.value = false;
                          }
                        } else if (action == 'category') {
                          final allCats = vm.categories.value;
                          final tempIds = <String>{};
                          final changed = await showDialog<bool>(context: context, builder: (c) => StatefulBuilder(
                            builder: (c, setDialogState) => AlertDialog(
                            title: const Text('移动分类'),
                            content: Column(mainAxisSize: MainAxisSize.min,
                              children: allCats.map((cat) => CheckboxListTile(
                                title: Text(cat.name),
                                value: tempIds.contains(cat.id),
                                onChanged: (v) {
                                  if (v == true) { tempIds.add(cat.id); } else { tempIds.remove(cat.id); }
                                  setDialogState(() {});
                                },
                              )).toList(),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
                              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('应用')),
                            ],
                          )));
                          if (changed == true) {
                            for (final id in selectedIds.value) {
                              await vm.updateBookCategories(id, tempIds.toList());
                            }
                          }
                        } else if (action == 'status') {
                          await showDialog(context: context, builder: (c) => AlertDialog(
                            title: const Text('更改状态'),
                            content: Column(mainAxisSize: MainAxisSize.min, children: [
                              ListTile(title: const Text('阅读中'), onTap: () => Navigator.pop(c, 'reading')),
                              ListTile(title: const Text('未开始'), onTap: () => Navigator.pop(c, 'planned')),
                              ListTile(title: const Text('已读完'), onTap: () => Navigator.pop(c, 'completed')),
                            ]),
                          )).then((status) async {
                            if (status != null) {
                              final repo = getIt<BookRepository>();
                              for (final id in selectedIds.value) {
                                await repo.updateBookStatus(id, status);
                              }
                              await vm.loadBooks();
                            }
                          });
                        }
                      },
                      itemBuilder: (c) => [
                        const PopupMenuItem(value: 'delete', child: ListTile(
                          leading: Icon(Icons.delete_outline, color: Colors.red),
                          title: Text('删除', style: TextStyle(color: Colors.red)),
                          contentPadding: EdgeInsets.zero, dense: true,
                        )),
                        const PopupMenuItem(value: 'category', child: ListTile(
                          leading: Icon(Icons.category),
                          title: Text('移动分类'),
                          contentPadding: EdgeInsets.zero, dense: true,
                        )),
                        const PopupMenuItem(value: 'status', child: ListTile(
                          leading: Icon(Icons.check_circle_outline),
                          title: Text('更改状态'),
                          contentPadding: EdgeInsets.zero, dense: true,
                        )),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  void _showBookActions(BuildContext context, BookshelfViewModel vm, Book book) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.category),
          title: const Text('编辑分类'),
          onTap: () => Navigator.pop(c, 'category'),
        ),
        ListTile(
          leading: const Icon(Icons.check_circle_outline, color: DesignTokens.primary),
          title: Text(book.status == BookStatus.reading ? '标记为未开始' : '标记为阅读中'),
          onTap: () => Navigator.pop(c, 'status'),
        ),
        if (book.coverPath == null)
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: const Text('补提取封面'),
            onTap: () => Navigator.pop(c, 'cover'),
          ),
      ]),
    );
    if (result == 'category') {
      final allCats = vm.categories.value;
      final currentIds = await vm.getBookCategoryIds(book.bookId);
      if (!context.mounted) return;
      final tempSelected = Set<String>.from(currentIds);
      final selected = await showDialog<Set<String>>(
        context: context,
        builder: (c) => StatefulBuilder(builder: (c, setDialogState) => AlertDialog(
          title: const Text('选择分类'),
          content: Column(mainAxisSize: MainAxisSize.min,
            children: allCats.map((cat) => CheckboxListTile(
              title: Text(cat.name),
              value: tempSelected.contains(cat.id),
              onChanged: (v) {
                if (v == true) { tempSelected.add(cat.id); } else { tempSelected.remove(cat.id); }
                setDialogState(() {});
              },
            )).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
            FilledButton(onPressed: () => Navigator.pop(c, Set.from(tempSelected)), child: const Text('确定')),
          ],
        )),
      );
      if (selected != null) {
        await vm.updateBookCategories(book.bookId, selected.toList());
      }
    } else if (result == 'status') {
      final repo = getIt<BookRepository>();
      final newStatus = book.status == BookStatus.reading ? BookStatus.planned : BookStatus.reading;
      await repo.updateBookStatus(book.bookId, newStatus.name);
      await vm.loadBooks();
    } else if (result == 'cover') {
      if (!context.mounted) return;
      if (await _reExtractCover(context, book)) await vm.loadBooks();
    }
  }

  Future<bool> _reExtractCover(BuildContext context, Book book) async {
    final repo = getIt<BookRepository>();
    final coverService = getIt<RustCoverService>();
    if (!coverService.supportsCoverExtraction(book.filePath)) return false;
    final appDir = await getApplicationDocumentsDirectory();
    final coverDir = p.join(appDir.path, 'zephyr_reader', 'covers');
    final coverPath = await coverService.extractBookCover(
      filePath: book.filePath, outputDir: coverDir,
    );
    if (coverPath.isEmpty) return false;
    final updated = Book(
      bookId: book.bookId, filePath: book.filePath,
      fileHash: book.fileHash, fileSize: book.fileSize, fileMtime: book.fileMtime,
      title: book.title, author: book.author, description: book.description,
      coverPath: coverPath, chapterCount: book.chapterCount,
      totalCharacters: book.totalCharacters, format: book.format,
      addedAt: book.addedAt, lastOpenedAt: book.lastOpenedAt,
      status: book.status, isPinned: book.isPinned,
    );
    await repo.updateBook(updated);
    return true;
  }

  Future<void> _showImportDialog(BuildContext context, BookshelfViewModel vm) async {
    final repo = getIt<BookRepository>();
    final files = await repo.selectFiles(allowMultiple: false, allowedExtensions: ['txt', 'epub', 'pdf']);
    if (files == null || files.isEmpty || !context.mounted) return;
    try {
      final book = await repo.importBook(files.first);
      if (book != null) {
        await vm.loadBooks();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已导入：${book.title}'), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)),
        );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败：$e'), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  Future<void> _showScanDialog(BuildContext context, BookshelfViewModel vm) async {
    final repo = getIt<BookRepository>();
    final folder = await repo.selectFolder();
    if (folder == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在扫描文件夹...'), duration: Duration(seconds: 1)),
    );
    final files = await repo.scanFolder(folder);
    if (files.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到书籍文件')),
        );
      }
      return;
    }
    var count = 0;
    for (final file in files) {
      if (await repo.importBook(file) != null) count++;
    }
    await vm.loadBooks();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('扫描完成，导入了 $count 本书'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _showSettingsSheet(BuildContext context, BookshelfViewModel vm) {
    showModalBottomSheet(
      context: context,
      builder: (c) => StatefulBuilder(builder: (context, setState) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('书架设置',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: DesignTokens.textPrimary)),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text('显示阅读进度'),
                value: vm.showReadingProgress.value,
                onChanged: (v) { vm.setShowReadingProgress(v); setState(() {}); },
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: const Text('显示最近阅读'),
                value: vm.showRecentReading.value,
                onChanged: (v) { vm.setShowRecentReading(v); setState(() {}); },
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              const Text('默认排序',
                style: TextStyle(fontSize: 12, color: DesignTokens.textSecondary, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              DropdownButton<BookshelfSortType>(
                value: vm.defaultSortType.value,
                isExpanded: true,
                underline: const SizedBox(),
                items: BookshelfSortType.values.map((t) =>
                  DropdownMenuItem(value: t, child: Text(t.displayName)),
                ).toList(),
                onChanged: (v) { if (v != null) vm.setDefaultSortType(v); },
              ),
            ],
          ),
        );
      }),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'reading': return '阅读中';
      case 'completed': return '已读完';
      default: return '未开始';
    }
  }
}

class _BookCover extends StatelessWidget {
  final Book book;
  final ThemeData theme;
  final String statusLabel;
  const _BookCover({required this.book, required this.theme, required this.statusLabel});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: book.coverPath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(book.coverPath!), fit: BoxFit.cover,
                      width: double.infinity, height: double.infinity,
                      errorBuilder: (_, _, _) => _placeholder(),
                    ),
                  )
                : _placeholder(),
          ),
        ),
        const SizedBox(height: 8),
        Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: DesignTokens.textPrimary, height: 1.3),
        ),
        const SizedBox(height: 2),
        Text(statusLabel, style: const TextStyle(fontSize: 11, color: DesignTokens.textSecondary)),
      ],
    );
  }

  Widget _placeholder() => Center(
    child: Icon(Icons.book_rounded, size: 28, color: theme.colorScheme.primary.withValues(alpha: 0.4)),
  );
}

class _StatusTab {
  final BookStatus? status;
  final String label;
  const _StatusTab(this.status, this.label);
}
