import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/features/search/application/book_search_view_model.dart';
import 'package:zephyr_reader/features/search/page/widgets/search_result_tile.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';

/// 书籍内搜索页面。
///
/// 在指定书籍内搜索文本内容，展示匹配结果和上下文。
/// 使用 [BookSearchViewModel] 管理搜索状态。
class BookSearchPage extends HookWidget {
  final String bookId;
  const BookSearchPage({super.key, this.bookId = ''});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final vm = useMemoized(() => BookSearchViewModel(bookId: bookId));
    final AsyncState<List<SearchResult>> bookResults = useSignalValue(
      vm.results,
    );
    final String query = useSignalValue(vm.query);
    final searchTimer = useRef<Timer?>(null);

    useEffect(() {
      return () {
        searchTimer.value?.cancel();
        vm.dispose();
      };
    }, [vm]);

    void onSearchChanged(String value) {
      vm.query.value = value;
      searchTimer.value?.cancel();
      searchTimer.value = Timer(
        const Duration(milliseconds: 300),
        () => vm.search(value),
      );
    }

    void onSearchSubmit() {
      searchTimer.value?.cancel();
      vm.search(vm.query.value);
    }

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: bookId.isEmpty
                ? l10n.bookSearchHintAll
                : l10n.bookSearchHint,
            border: InputBorder.none,
            hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          style: TextStyle(color: theme.colorScheme.onSurface),
          onChanged: onSearchChanged,
          onSubmitted: (_) => onSearchSubmit(),
        ),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.magnifyingGlass),
            onPressed: onSearchSubmit,
            tooltip: l10n.search,
          ),
          if (bookResults.hasValue)
            IconButton(
              icon: const Icon(PhosphorIconsRegular.x),
              onPressed: () => vm.clear(),
              tooltip: l10n.clear,
            ),
        ],
      ),
      body: _buildBody(theme, l10n, bookResults, query, onSearchSubmit),
    );
  }

  Widget _buildBody(
    ThemeData theme,
    AppLocalizations l10n,
    AsyncState<List<SearchResult>> results,
    String query,
    VoidCallback onRetry,
  ) {
    return results.map(
      data: (List<SearchResult> results) {
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
                  query.isEmpty
                      ? l10n.searchEnterKeyword
                      : l10n.searchNoResults,
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (query.isNotEmpty) ...[
                  SizedBox(height: DesignTokens.spacing(Spacing.sm)),
                  Text(
                    l10n.searchTryOtherKeywords,
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
            horizontal: DesignTokens.spacing(Spacing.md),
            vertical: DesignTokens.spacing(Spacing.sm),
          ),
          itemCount: results.length,
          separatorBuilder: (_, _) =>
              Divider(height: 0.5, color: theme.dividerColor),
          itemBuilder: (context, index) =>
              SearchResultTile(result: results[index]),
        );
      },
      error: () => Center(
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
              l10n.searchFailed,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            SizedBox(height: DesignTokens.spacing(Spacing.md)),
            FilledButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}
