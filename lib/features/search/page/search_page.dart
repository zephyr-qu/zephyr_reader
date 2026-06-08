import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/search/application/search_view_model.dart';
import 'package:zephyr_reader/features/search/application/services/search_history_service.dart';
import 'package:zephyr_reader/features/search/page/search_results.dart';
import 'package:zephyr_reader/features/search/page/widgets/search_history.dart';
import 'package:zephyr_reader/features/search/page/widgets/search_result_header.dart';
import 'package:zephyr_reader/features/search/page/widgets/search_results_view.dart';

/// 全局搜索页面。
///
/// 支持搜索所有已索引书籍的文本内容，展示搜索结果摘要。
/// 使用 [SearchViewModel] 管理搜索状态和结果。
class SearchPage extends HookWidget {
  late final SearchViewModel vm = getIt<SearchViewModel>();
  SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = useTextEditingController();
    final focusNode = useFocusNode();
    final history = useMemoized(() => SearchHistoryService());
    final debounceTimer = useRef<Timer?>(null);
    final searchText = useSignal('');

    // VM signal bindings
    final isSearching = useSignalValue<bool, Signal<bool>>(vm.isSearching);
    final hasSearched = useSignalValue<bool, Signal<bool>>(vm.hasSearched);
    final searchError = useSignalValue<String?, Signal<String?>>(
      vm.searchError,
    );

    final searchResults = useComputed(() {
      if (!vm.hasSearched.value) return null;
      if (vm.searchError.value != null) return null;
      return vm.searchResults.value.value;
    });

    // Debounced search effect
    useEffect(() {
      void onTextChanged() {
        searchText.value = controller.text;
        debounceTimer.value?.cancel();
        final text = controller.text;
        if (text.trim().isEmpty) {
          vm.clear();
          return;
        }
        debounceTimer.value = Timer(const Duration(milliseconds: 300), () {
          vm.doFullSearch(text.trim());
          history.addHistory(text.trim());
        });
      }

      controller.addListener(onTextChanged);
      return () {
        controller.removeListener(onTextChanged);
        debounceTimer.value?.cancel();
      };
    }, []);

    // Autofocus
    useEffect(() {
      focusNode.requestFocus();
      return null;
    }, []);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchHeader(
              context,
              theme,
              controller,
              focusNode,
              searchText.value,
              vm,
              history,
              onClear: () {
                controller.clear();
                debounceTimer.value?.cancel();
                vm.clear();
              },
              onSearch: (value) {
                debounceTimer.value?.cancel();
                vm.doFullSearch(value);
                history.addHistory(value);
              },
            ),
            if (hasSearched && searchResults.value != null)
              SearchSummaryBar(results: searchResults.value!),
            Expanded(
              child: _buildBody(
                context,
                theme,
                isSearching,
                hasSearched,
                searchError,
                searchResults.value,
                history,
                controller,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────── Search Header ────────────────

  Widget _buildSearchHeader(
    BuildContext context,
    ThemeData theme,
    TextEditingController controller,
    FocusNode focusNode,
    String currentText,
    SearchViewModel vm,
    SearchHistoryService history, {
    required VoidCallback onClear,
    required ValueChanged<String> onSearch,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '搜索书籍、笔记、生词...',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 8),
                    child: Icon(
                      PhosphorIconsRegular.magnifyingGlass,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  suffixIcon: currentText.isNotEmpty
                      ? IconButton(
                          icon: const Icon(PhosphorIconsRegular.x, size: 16),
                          onPressed: onClear,
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                style: theme.textTheme.bodyLarge,
                textInputAction: TextInputAction.search,
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    onSearch(value.trim());
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => context.pop(),
            child: Text(
              '取消',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────── Body ────────────────

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    bool isLoading,
    bool hasSearched,
    String? error,
    SearchResults? results,
    SearchHistoryService history,
    TextEditingController controller,
  ) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIconsRegular.warningCircle,
              size: 40,
              color: theme.colorScheme.error.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              '搜索出错',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => vm.doFullSearch(controller.text.trim()),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (results != null && results.totalCount == 0) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIconsRegular.magnifyingGlass,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              '未找到相关结果',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '试试其他关键词',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.6,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (results != null) {
      return SearchResultsView(results: results, query: controller.text.trim());
    }

    return SearchHistoryView(history: history, controller: controller, vm: vm);
  }
}
