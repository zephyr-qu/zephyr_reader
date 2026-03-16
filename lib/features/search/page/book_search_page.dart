/// 书籍搜索页面
library;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_hooks/signals_hooks.dart';

import '../../../../core/database/database.dart';
import '../../../../core/routing/route_constants.dart';
import '../../../../di/service_locator.dart';
import '../application/book_search_service.dart';

/// 书籍搜索页面
class BookSearchPage extends HookWidget {
  const BookSearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final searchService = useMemoized(
      () => BookSearchService(getIt<AppDatabase>()),
    );
    final searchResults = useSignal<List<SearchHit>>([]);
    final isSearching = useSignal(false);
    final searchQuery = useSignal('');
    final error = useSignal<String?>(null);

    // 初始化搜索服
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
            hintStyle: TextStyle(color: Colors.white70),
          ),
          style: const TextStyle(color: Colors.white),
          onChanged: (value) {
            searchQuery.value = value;
          },
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              _performSearch(searchService, searchResults, isSearching, error);
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              if (searchQuery.value.isNotEmpty) {
                _performSearch(
                  searchService,
                  searchResults,
                  isSearching,
                  error,
                );
              }
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
      body: Watch.builder(
        builder: (context) {
          if (isSearching.value) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('搜索..'),
                ],
              ),
            );
          }

          if (error.value != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text('搜索失败{error.value}'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      error.value = null;
                      if (searchQuery.value.isNotEmpty) {
                        _performSearch(
                          searchService,
                          searchResults,
                          isSearching,
                          error,
                        );
                      }
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
                  Icon(
                    Icons.search_off,
                    size: 64,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: .3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    searchQuery.value.isEmpty ? '请输入搜索关键词' : '未找到相关结',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  if (searchQuery.value.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '建议：尝试其他关键词或检查拼',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: results.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final result = results[index];
              return _SearchResultTile(result: result);
            },
          );
        },
      ),
    );
  }

  Future<void> _performSearch(
    BookSearchService searchService,
    Signal<List<SearchHit>> searchResults,
    Signal<bool> isSearching,
    Signal<String?> error,
  ) async {
    isSearching.value = true;
    error.value = null;

    try {
      final results = await searchService.search(searchQuery.value);
      searchResults.value = results;
    } catch (e) {
      error.value = e.toString();
    } finally {
      isSearching.value = false;
    }
  }
}

/// 搜索结果
class _SearchResultTile extends StatelessWidget {
  final SearchHit result;

  const _SearchResultTile({required this.result});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.book),
      title: Text(
        result.chapterTitle,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            result.bookTitle,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            result.snippet,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.8),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${(result.score * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios, size: 16),
        ],
      ),
      onTap: () {
        // 跳转到书籍阅读页
        context.goNamed(
          RouteNames.reader,
          pathParameters: {
            'bookId': result.bookId.toString(),
            'chapterId': result.chapterId.toString(),
          },
        );
      },
    );
  }
}
