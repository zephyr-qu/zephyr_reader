import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/core/presentation/widgets/snack_utils.dart';
import 'package:zephyr_reader/features/reader/application/cache_manage_view_model.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';
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
    final vm = useMemoized(() => CacheManageViewModel());
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
    final AsyncState<IndexStats> indexStats =
        useSignalValue<AsyncState<IndexStats>, Signal<AsyncState<IndexStats>>>(
          vm.searchIndexStats,
        );

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.cacheManage)),
      body: _buildBody(context, theme, vm, books, progressList, indexStats),
    );
  }

  Future<void> _clearProgress(
    BuildContext context,
    String bookId,
    String title,
    CacheManageViewModel vm,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    await vm.clearProgress(bookId);
    if (context.mounted) {
      showInfoSnack(context, l10n.clearedProgress(title));
    }
  }

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    CacheManageViewModel vm,
    AsyncState<List<Book>> books,
    AsyncState<List<BookWithProgress>> progressList,
    AsyncState<IndexStats> indexStats,
  ) {
    final l10n = AppLocalizations.of(context)!;
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
              Text(
                l10n.loadFailed,
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
            _buildOverview(
              context,
              theme,
              vm,
              bookList,
              progressData,
              indexStats,
            ),
            Text(
              l10n.readingProgress,
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
                    l10n.noProgressData,
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
                    l10n.cacheInfoTip,
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
    AsyncState<IndexStats> indexStats,
  ) {
    final l10n = AppLocalizations.of(context)!;
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
                l10n.bookCount,
                PhosphorIconsRegular.bookOpenText,
              ),
              const SizedBox(width: 24),
              _overviewItem(
                theme,
                '${progressList.length}',
                l10n.withProgress,
                PhosphorIconsRegular.trendUp,
              ),
              const SizedBox(width: 24),
              _overviewItem(
                theme,
                '${books.fold<int>(0, (s, b) => s + (b.chapterCount))}',
                l10n.labelTotalChapters,
                PhosphorIconsRegular.article,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSearchIndexSection(context, theme, indexStats),
        ],
      ),
    );
  }

  Widget _buildSearchIndexSection(
    BuildContext context,
    ThemeData theme,
    AsyncState<IndexStats> indexStats,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return indexStats.map(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object err, _) => Row(
        children: [
          Icon(
            PhosphorIconsRegular.warningCircle,
            size: 14,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 6),
          Text(
            l10n.indexLoadFailed,
            style: TextStyle(fontSize: 12, color: theme.colorScheme.error),
          ),
        ],
      ),
      data: (stats) => Row(
        children: [
          _overviewItem(
            theme,
            '${stats.totalChunks}',
            l10n.indexChunks,
            PhosphorIconsRegular.database,
          ),
          const SizedBox(width: 24),
          _overviewItem(
            theme,
            '${stats.indexedBooks}',
            l10n.indexBooks,
            PhosphorIconsRegular.bookOpenText,
          ),
          const SizedBox(width: 24),
          _overviewItem(
            theme,
            '${stats.indexedChapters}',
            l10n.indexChapters,
            PhosphorIconsRegular.article,
          ),
        ],
      ),
    );
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
    final l10n = AppLocalizations.of(context)!;
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
                    '${l10n.chapterN(progress.chapterIndex)} · $dateStr',
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
            tooltip: l10n.clearProgress,
          ),
        ],
      ),
    );
  }
}
