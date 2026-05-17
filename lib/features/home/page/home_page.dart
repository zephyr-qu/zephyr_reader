import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zephyr_reader/core/local/rust_storage_service.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _storage = getIt<RustStorageService>();
  List<Book> _recentBooks = [];
  GlobalStats? _stats;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _storage.getRecentlyReadBooks(4),
        _storage.getGlobalReadingStats(),
      ]);
      if (mounted) {
        setState(() {
          _recentBooks = results[0] as List<Book>;
          _stats = results[1] as GlobalStats?;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loaded = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 6) {
      greeting = '夜深了';
    } else if (hour < 12) {
      greeting = '早上好';
    } else if (hour < 14) {
      greeting = '中午好';
    } else if (hour < 18) {
      greeting = '下午好';
    } else {
      greeting = '晚上好';
    }

    final currentBook = _recentBooks.isNotEmpty ? _recentBooks[0] : null;

    return Scaffold(
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(greeting,
                    style: const TextStyle(fontSize: 13, color: DesignTokens.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  const Text('继续阅读',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700,
                      color: DesignTokens.textPrimary, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: _statCard(theme, '${_stats?.consecutiveReadingDays ?? 0}', '连续天数')),
                      const SizedBox(width: 10),
                      Expanded(child: _statCard(theme, '${_stats?.totalBooksCount ?? 0}', '藏书')),
                      const SizedBox(width: 10),
                      Expanded(child: _statCard(theme, '${_stats?.booksCompletedCount ?? 0}', '已读完')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (currentBook != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _buildHero(context, theme, currentBook),
              ),
            ),
          const SliverPadding(padding: EdgeInsets.only(top: 32)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 60),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('最近阅读',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: DesignTokens.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 140,
                    child: _recentBooks.isEmpty
                        ? Center(
                            child: Text(_loaded ? '暂无阅读记录' : '加载中…',
                              style: const TextStyle(color: DesignTokens.textSecondary),
                            ),
                          )
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _recentBooks.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 14),
                            itemBuilder: (context, index) {
                              return _recentCard(context, _recentBooks[index]);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(ThemeData theme, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.5),
      ),
      child: Column(
        children: [
          Text(value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
              color: DesignTokens.primary, letterSpacing: -0.3),
          ),
          const SizedBox(height: 4),
          Text(label,
            style: const TextStyle(fontSize: 11, color: DesignTokens.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context, ThemeData theme, Book book) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: 72, height: 100,
              color: theme.colorScheme.primaryContainer,
              child: Icon(Icons.book_rounded, size: 28,
                color: theme.colorScheme.primary.withValues(alpha: 0.4),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(book.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600,
                    color: DesignTokens.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(book.author ?? '未知作者',
                  style: const TextStyle(fontSize: 12, color: DesignTokens.textSecondary),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: FilledButton(
                    onPressed: () => context.pushNamed(RouteNames.bookshelf),
                    style: FilledButton.styleFrom(
                      backgroundColor: DesignTokens.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('继续阅读', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentCard(BuildContext context, Book book) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => context.pushNamed(RouteNames.bookshelf),
      child: SizedBox(
        width: 72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 72, height: 96,
                color: theme.colorScheme.primaryContainer,
                child: Icon(Icons.book_rounded, size: 24,
                  color: theme.colorScheme.primary.withValues(alpha: 0.4),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(book.title,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, height: 1.3, color: DesignTokens.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
