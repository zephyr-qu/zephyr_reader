library;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/reader/data/repositories/rust_reader_repository.dart';
import 'package:zephyr_reader/src/rust/api/data/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/api/data/progress.dart' as progress_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

class CacheManagePage extends StatefulWidget {
  final String? bookId;
  const CacheManagePage({super.key, this.bookId});

  @override
  State<CacheManagePage> createState() => _CacheManagePageState();
}

class _CacheManagePageState extends State<CacheManagePage> {
  final _repo = getIt<ReaderRepository>();
  List<Book> _books = [];
  List<BookWithProgress> _progressList = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final books = await book_api.listBooks();
      final allProgress = await progress_api.listAllProgresses();
      if (mounted) {
        setState(() {
          _books = books;
          _progressList = allProgress;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _clearAllCache() async {
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
      _repo.clearAllCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已清空全部缓存'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _clearProgress(String bookId, String title) async {
    await progress_api.clearProgress(bookId: bookId);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已清除《$title》阅读进度'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _clearProgressCache() {
    _repo.clearProgressCache();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已清除内存中的进度缓存'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('缓存管理'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.trashSimple),
            onPressed: _clearAllCache,
            tooltip: '清空全部缓存',
          ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _buildOverview(theme),
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
        if (_progressList.isEmpty)
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
          ..._progressList.map((p) => _buildProgressItem(theme, p)),
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

  Widget _buildOverview(ThemeData theme) {
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
                '${_books.length}',
                '书籍数',
                PhosphorIconsRegular.bookOpenText,
              ),
              const SizedBox(width: 24),
              _overviewItem(
                theme,
                '${_progressList.length}',
                '有进度',
                PhosphorIconsRegular.trendUp,
              ),
              const SizedBox(width: 24),
              _overviewItem(
                theme,
                '${_books.fold<int>(0, (s, b) => s + (b.chapterCount))}',
                '总章节',
                PhosphorIconsRegular.article,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _clearAllCache,
              icon: const Icon(PhosphorIconsRegular.trash, size: 18),
              label: const Text('清空全部缓存'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _clearProgressCache,
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

  Widget _buildProgressItem(ThemeData theme, BookWithProgress item) {
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
                const SizedBox(height: 2),
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
            onPressed: () => _clearProgress(book.bookId, bookTitle),
            tooltip: '清除进度',
          ),
        ],
      ),
    );
  }
}
