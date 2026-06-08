import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';

import 'package:zephyr_reader/features/search/application/search_view_model.dart';
import 'package:zephyr_reader/features/search/application/services/search_history_service.dart';

/// 搜索历史视图。
///
/// 显示搜索历史记录列表，支持点击重新搜索和清除历史。
class SearchHistoryView extends StatelessWidget {
  final SearchHistoryService history;
  final TextEditingController controller;
  final SearchViewModel vm;

  const SearchHistoryView({
    super.key,
    required this.history,
    required this.controller,
    required this.vm,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final historyList = history.getHistory();
    if (historyList.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIconsRegular.magnifyingGlass,
              size: 40,
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.searchHint,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.searchHistory,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              GestureDetector(
                onTap: history.clearHistory,
                child: Text(
                  l10n.clear,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: historyList.map((h) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: () {
                    controller.text = h;
                    controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: h.length),
                    );
                    vm.doFullSearch(h);
                  },
                  child: Text(h, style: theme.textTheme.bodyMedium),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
