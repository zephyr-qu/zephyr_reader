library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/core/local/rust_search_service.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import '../../../../core/routing/route_constants.dart';
import '../application/services/full_text_search_service.dart';

class BookSearchPage extends HookWidget {
  const BookSearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final searchService = useMemoized(() => FullTextSearchService(getIt<RustSearchService>()));
    final searchResults = useSignal<List<SearchHit>>([]);
    final isSearching = useSignal(false);
    final searchQuery = useSignal('');
    final error = useSignal<String?>(null);

    useEffect(() {
      searchService.init();
      return null;
    }, []);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '搜索书籍内容...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: DesignTokens.textSecondary),
          ),
          style: const TextStyle(color: DesignTokens.textPrimary),
          onChanged: (value) => searchQuery.value = value,
          onSubmitted: (value) {
            if (value.isNotEmpty) _performSearch(searchService, searchResults, isSearching, error, searchQuery);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              if (searchQuery.value.isNotEmpty) _performSearch(searchService, searchResults, isSearching, error, searchQuery);
            },
          ),
          if (searchResults.value.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                searchResults.value = [];
                searchQuery.value = '';
                error.value = null;
              },
            ),
        ],
      ),
      body: Watch.builder(builder: (context) {
        if (isSearching.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (error.value != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: DesignTokens.primary),
                const SizedBox(height: 16),
                const Text('搜索失败', style: TextStyle(color: DesignTokens.textSecondary)),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    error.value = null;
                    if (searchQuery.value.isNotEmpty) _performSearch(searchService, searchResults, isSearching, error, searchQuery);
                  },
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }

        final results = searchResults.value;

        if (results.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: DesignTokens.textSecondary.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                Text(
                  searchQuery.value.isEmpty ? '请输入搜索关键词' : '未找到相关结果',
                  style: const TextStyle(fontSize: 16, color: DesignTokens.textPrimary),
                ),
                if (searchQuery.value.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('尝试其他关键词', style: TextStyle(fontSize: 14, color: DesignTokens.textSecondary)),
                ],
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          itemCount: results.length,
          separatorBuilder: (_, _) => const Divider(height: 0.5, color: DesignTokens.divider),
          itemBuilder: (context, index) {
            final result = results[index];
            return _SearchResultTile(result: result);
          },
        );
      }),
    );
  }

  Future<void> _performSearch(
    FullTextSearchService searchService,
    Signal<List<SearchHit>> searchResults,
    Signal<bool> isSearching,
    Signal<String?> error,
    Signal<String> searchQuery,
  ) async {
    isSearching.value = true;
    error.value = null;
    try {
      searchResults.value = await searchService.search(bookId: '', query: searchQuery.value);
    } catch (e) {
      error.value = e.toString();
    } finally {
      isSearching.value = false;
    }
  }
}

class _SearchResultTile extends StatelessWidget {
  final SearchHit result;

  const _SearchResultTile({required this.result});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.goNamed(RouteNames.reader, pathParameters: {
        'bookId': result.bookId,
        'chapterId': result.chapterId.toString(),
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: DesignTokens.divider, width: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.book_rounded, size: 20, color: DesignTokens.primary.withValues(alpha: 0.5)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result.chapterTitle,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: DesignTokens.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(result.snippet,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: DesignTokens.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('${(result.score * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 12, color: DesignTokens.primary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
