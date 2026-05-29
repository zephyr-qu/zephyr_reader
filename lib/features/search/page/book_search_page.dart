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
    final searchResults = useSignal<List<SearchResult>>([]);
    final isSearching = useSignal(false);
    final searchQuery = useSignal('');
    final error = useSignal<String?>(null);

    useEffect(() {
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
        ),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.magnifyingGlass),
            onPressed: () {},
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
      body: _buildBody(
        theme,
        isSearching.value,
        error.value,
        searchResults.value,
        searchQuery.value,
        () {
          error.value = null;
        },
      ),
    );
  }

  Widget _buildBody(
    ThemeData theme,
    bool isSearching,
    String? error,
    List<SearchResult> results,
    String query,
    VoidCallback onRetry,
  ) {
    if (isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
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
            FilledButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      );
    }

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIconsRegular.magnifyingGlassMinus,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            SizedBox(height: DesignTokens.spacing(Spacing.md)),
            Text(
              query.isEmpty ? '请输入搜索关键词' : '未找到相关结果',
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (query.isNotEmpty) ...[
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
      itemBuilder: (context, index) =>
          _SearchResultTile(result: results[index]),
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
          'bookId': result.bookId,
          'chapterId': result.chapterId,
        },
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.dividerColor, width: 0.5),
          ),
        ),
        child: ListTile(
          title: Text(result.snippet),
          subtitle: Text(result.chapterTitle),
        ),
      ),
    );
  }
}
