

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/presentation/widgets/snack_utils.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/reader/application/cache_manage_view_model.dart';
import 'package:zephyr_reader/features/reader/data/repositories/rust_reader_repository.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class CacheManagePage extends HookWidget {
  late final ReaderRepository repo = getIt<ReaderRepository>();
  final String? bookId;

  CacheManagePage({super.key, this.bookId});

  @override
  Widget build(BuildContext context) {
    final vm = useMemoized(
      () => CacheManageViewModel(repo: repo, bookId: bookId),
    );
    final books = useSignalValue<List<Book>, Signal<List<Book>>>(vm.books);
    final progressList =
        useSignalValue<List<BookWithProgress>, Signal<List<BookWithProgress>>>(
          vm.progressList,
        );
    final loaded = useSignalValue<bool, Signal<bool>>(vm.loaded);

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('缓存管理'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.trashSimple),
            onPressed: () => _clearAllCache(context, vm),
            tooltip: '清空全部缓存',
          ),
        ],
      ),
      body: _buildBody(context, theme, vm, books, progressList, loaded),
    );
  }

  Future<void> _clearAllCache(
    BuildContext context,
    CacheManageViewModel vm,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('清空全部缓存'),
        content: const Text('将清除所有阅读器缓存内容，包括章节内容和格式数据。下次阅读时需要重新加载。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      vm.clearAllCache();
      if (context.mounted) {
        showInfoSnack(context, '已清空全部缓存');
      }
    }
  }

  Future<void> _clearProgress(
    BuildContext context,
    String bookId,
    String title,
    CacheManageViewModel vm,
  ) async {
    await vm.clearProgress(bookId);
    if (context.mounted) {
      showInfoSnack(context, '已清除《$title》阅读进度');
    }
  }

  void _clearProgressCache(BuildContext context, CacheManageViewModel vm) {
    vm.clearProgressCache();
    showInfoSnack(context, '已清除内存中的进度缓存');
  }

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    CacheManageViewModel vm,
    List<Book> books,
    List<BookWithProgress> progressList,
    bool loaded,
  ) {
    if (!loaded) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _buildOverview(context, theme, vm, books, progressList),
        const SizedBox(height: 24),
        Text(
          '阅读进度',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
        const Divider(height: 12),
        if (progressList.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                '暂无阅读进度数据',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          )
        else
          ...progressList.map((p) => _buildProgressItem(context, theme, p, vm)),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              PhosphorIconsRegular.info,
              size: 14,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '缓存包含已加载的章节内容。清空后需重新加载，不影响书籍文件和阅读进度',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOverview(
    BuildContext context,
    ThemeData theme,
    CacheManageViewModel vm,
    List<Book> books,
    List<BookWithProgress> progressList,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _overviewItem(
                theme,
                '${books.length}',
                '书籍数',
                PhosphorIconsRegular.bookOpenText,
              ),
              const SizedBox(width: 24),
              _overviewItem(
                theme,
                '${progressList.length}',
                '有进度',
                PhosphorIconsRegular.trendUp,
              ),
              const SizedBox(width: 24),
              _overviewItem(
                theme,
                '${books.fold<int>(0, (s, b) => s + (b.chapterCount))}',
                '总章节',
                PhosphorIconsRegular.article,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _clearAllCache(context, vm),
              icon: const Icon(PhosphorIconsRegular.trash, size: 18),
              label: const Text('清空全部缓存'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _clearProgressCache(context, vm),
              icon: const Icon(PhosphorIconsRegular.cpu, size: 18),
              label: const Text('清除进度缓存'),
            ),
          ),
          const SizedBox(height: 16),
          _buildSearchIndexSection(theme),
        ],
      ),
    );
  }

  Widget _buildSearchIndexSection(ThemeData theme) {
    return const SizedBox.shrink();
  }

  Widget _overviewItem(
    ThemeData theme,
    String value,
    String label,
    IconData icon,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressItem(
    BuildContext context,
    ThemeData theme,
    BookWithProgress item,
    CacheManageViewModel vm,
  ) {
    final progress = item.progress;
    final book = item.book;
    final bookTitle = book.title;
    final dateStr = progress != null
        ? '${progress.lastReadAt.month}/${progress.lastReadAt.day} ${progress.lastReadAt.hour.toString().padLeft(2, '0')}:${progress.lastReadAt.minute.toString().padLeft(2, '0')}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bookTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (progress != null) const SizedBox(height: 2),
                if (progress != null)
                  Text(
                    '第 ${progress.chapterIndex} 章 · $dateStr',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              PhosphorIconsRegular.trash,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            onPressed: () =>
                _clearProgress(context, book.bookId, bookTitle, vm),
            tooltip: '清除进度',
          ),
        ],
      ),
    );
  }
}
