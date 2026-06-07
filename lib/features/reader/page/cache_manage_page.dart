import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/presentation/widgets/snack_utils.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/reader/application/cache_manage_view_model.dart';
import 'package:zephyr_reader/features/reader/data/repositories/rust_reader_repository.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 缓存管理页面。
///
/// 查看和清理阅读排版缓存，支持按书籍粒度操作。
/// 使用 [CacheManageViewModel] 管理缓存数据。
class CacheManagePage extends HookWidget {
  final String? bookId;

  const CacheManagePage({super.key, this.bookId});

  @override
  Widget build(BuildContext context) {
    final repo = useMemoized(() => getIt<ReaderRepository>());
    final vm = useMemoized(
      () => CacheManageViewModel(repo: repo, bookId: bookId),
    );
    useEffect(() {
      vm.load();
      return null;
    }, []);
    final AsyncState<List<Book>> books =
        useSignalValue<AsyncState<List<Book>>, AsyncSignal<List<Book>>>(
          vm.books,
        );
    final AsyncState<List<BookWithProgress>> progressList =
        useSignalValue<
          AsyncState<List<BookWithProgress>>,
          AsyncSignal<List<BookWithProgress>>
        >(vm.progressList);

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('缓存管理')),
      body: _buildBody(context, theme, vm, books, progressList),
    );
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
    AsyncState<List<Book>> books,
    AsyncState<List<BookWithProgress>> progressList,
  ) {
    return books.map(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                PhosphorIconsRegular.warningCircle,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                '加载失败',
                style: TextStyle(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$err',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      data: (bookList) {
        final progressData = progressList.value ?? <BookWithProgress>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            _buildOverview(context, theme, vm, bookList, progressData),
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
            if (progressData.isEmpty)
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
              ...progressData.map(
                (p) => _buildProgressItem(context, theme, p, vm),
              ),
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
      },
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
