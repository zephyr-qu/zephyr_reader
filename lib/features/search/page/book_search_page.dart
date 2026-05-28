library;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';
import '../../../../core/routing/route_constants.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';

class BookSearchPage extends HookWidget {
  final String bookId;
  const BookSearchPage({super.key, this.bookId = ''});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // final searchService = useMemoized(() => getIt<Search>());
    final searchResults = useSignal<List<SearchResult>>([]);
    final isSearching = useSignal(false);
    final searchQuery = useSignal('');
    final error = useSignal<String?>(null);

    useEffect(() {
      // searchService.init();
      return null;
    }, []);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          decoration: InputDecoration(
            hintText: bookId.isEmpty ? '搜索所有书籍内容...' : '搜索书籍内容...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          style: TextStyle(color: theme.colorScheme.onSurface),
          onChanged: (value) => searchQuery.value = value,
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              // _performSearch(
              // searchService,
              // searchResults,
              // isSearching,
              // error,
              // searchQuery,
              // );
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.magnifyingGlass),
            onPressed: () {
              if (searchQuery.value.isNotEmpty) {
                // _performSearch(
                //   searchService,
                //   searchResults,
                //   isSearching,
                //   error,
                //   searchQuery,
                // );
              }
            },
            tooltip: '搜索',
          ),
          if (searchResults.value.isNotEmpty)
            IconButton(
              icon: const Icon(PhosphorIconsRegular.x),
              onPressed: () {
                searchResults.value = [];
                searchQuery.value = '';
                error.value = null;
              },
              tooltip: '清除',
            ),
        ],
      ),
      body: Watch.builder(
        builder: (context) {
          if (isSearching.value) {
            return const Center(child: CircularProgressIndicator());
          }

          if (error.value != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    PhosphorIconsRegular.warningCircle,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  SizedBox(height: DesignTokens.spacing(Spacing.md)),
                  Text(
                    '搜索失败',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  SizedBox(height: DesignTokens.spacing(Spacing.md)),
                  FilledButton(
                    onPressed: () {
                      error.value = null;
                      if (searchQuery.value.isNotEmpty) {
                        // _performSearch(
                        //   searchService,
                        //   searchResults,
                        //   isSearching,
                        //   error,
                        //   searchQuery,
                        // );
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
                    PhosphorIconsRegular.magnifyingGlassMinus,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.3,
                    ),
                  ),
                  SizedBox(height: DesignTokens.spacing(Spacing.md)),
                  Text(
                    searchQuery.value.isEmpty ? '请输入搜索关键词' : '未找到相关结果',
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (searchQuery.value.isNotEmpty) ...[
                    SizedBox(height: DesignTokens.spacing(Spacing.sm)),
                    Text(
                      '尝试其他关键词',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: DesignTokens.spacing(Spacing.sm),
            ),
            itemCount: results.length,
            separatorBuilder: (_, _) =>
                Divider(height: 0.5, color: theme.dividerColor),
            itemBuilder: (context, index) {
              final result = results[index];
              return _SearchResultTile(result: result);
            },
          );
        },
      ),
    );
  }

}

class _SearchResultTile extends StatelessWidget {
  final SearchResult result;

  const _SearchResultTile({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.goNamed(
        RouteNames.reader,
        pathParameters: {
          // 'bookId': result.bookId,
          // 'chapterId': result.chapterId.toString(),
        },
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.dividerColor, width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              PhosphorIconsRegular.book,
              size: 20,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            SizedBox(width: DesignTokens.spacing(Spacing.sm)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    // result.chapterTitle,
                    '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: DesignTokens.spacing(Spacing.xs)),
                  Text(
                    // result.snippet,
                    '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: DesignTokens.spacing(Spacing.sm)),
            Text(
              // '${(result.score * 100).toStringAsFixed(0)}%',
              '',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
