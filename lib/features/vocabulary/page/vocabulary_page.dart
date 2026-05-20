library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';

import 'package:zephyr_reader/features/vocabulary/application/vocabulary_view_model.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';

class VocabularyPage extends StatefulWidget {
  const VocabularyPage({super.key});

  @override
  State<VocabularyPage> createState() => _VocabularyPageState();
}

class _VocabularyPageState extends State<VocabularyPage> {
  final _vm = GetIt.I.get<VocabularyViewModel>();

  @override
  void initState() {
    super.initState();
    _vm.loadWords();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(PhosphorIconsRegular.caretLeft),
          onPressed: () => context.pop(),
          tooltip: '返回',
        ),
        title: const Text('生词本'),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowsClockwise),
            onPressed: () => _vm.refresh(),
            tooltip: '刷新',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildStatsRow(theme),
            Expanded(child: _buildWordList(theme)),
          ],
        ),
      ),
    );
  }

  static const _filters = <String?, String>{
    null: '全部',
    'learning': '学习中',
    'known': '已认识',
    'mastered': '已掌握',
  };

  Widget _buildStatsRow(ThemeData theme) {
    return Watch.builder(
      builder: (context) {
        final s = _vm.stats.value;
        if (s == null) {
          return SizedBox(height: DesignTokens.spacing(Spacing.sm));
        }
        final filterStatus = _vm.filterStatus.value;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('全部', s.totalWords.toString(), null,
                    filterStatus == null, theme),
                const SizedBox(width: 8),
                _filterChip('学习中', s.learningCount.toString(), 'learning',
                    filterStatus == 'learning', theme),
                const SizedBox(width: 8),
                _filterChip('已认识', s.knownCount.toString(), 'known',
                    filterStatus == 'known', theme),
                const SizedBox(width: 8),
                _filterChip('已掌握', s.masteredCount.toString(), 'mastered',
                    filterStatus == 'mastered', theme),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _filterChip(
      String label, String count, String? filterValue, bool selected, ThemeData theme) {
    return GestureDetector(
      onTap: () => _vm.setFilter(filterValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          '$label $count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? theme.colorScheme.primary : null,
          ),
        ),
      ),
    );
  }

  Widget _buildWordList(ThemeData theme) {
    return Watch.builder(
      builder: (context) {
        if (_vm.loading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        final err = _vm.error.value;
        if (err != null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  PhosphorIconsRegular.warningCircle,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  err,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: DesignTokens.spacing(Spacing.md)),
                FilledButton.tonal(
                  onPressed: () => _vm.loadWords(),
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }
        final items = _vm.words.value;
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  PhosphorIconsRegular.bookmarkSimple,
                  size: 48,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '暂无生词',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: EdgeInsets.symmetric(
            horizontal: DesignTokens.spacing(Spacing.md),
          ),
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = items[index];
            return RepaintBoundary(
              child: Dismissible(
                key: ValueKey(item.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.red,
                  child: const Icon(
                    PhosphorIconsRegular.trash,
                    color: Colors.white,
                  ),
                ),
                onDismissed: (_) => _vm.deleteWord(item.id),
                child: ListTile(
                  contentPadding: EdgeInsets.symmetric(
                    vertical: DesignTokens.spacing(Spacing.xs),
                  ),
                  title: Text(
                    item.word,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: item.pinyin.isNotEmpty
                      ? Text(
                          item.pinyin,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        )
                      : null,
                  trailing: PopupMenuButton<String>(
                    initialValue: item.status,
                    onSelected: (s) => _vm.updateStatus(item.id, s),
                    itemBuilder: (_) => [
                      if (item.status != 'learning')
                        const PopupMenuItem(
                          value: 'learning',
                          child: Text('学习中'),
                        ),
                      if (item.status != 'known')
                        const PopupMenuItem(value: 'known', child: Text('已认识')),
                      if (item.status != 'mastered')
                        const PopupMenuItem(
                          value: 'mastered',
                          child: Text('已掌握'),
                        ),
                    ],
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: DesignTokens.spacing(Spacing.sm),
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor(
                          item.status,
                        ).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _statusLabel(item.status),
                        style: TextStyle(
                          fontSize: 12,
                          color: _statusColor(item.status),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'known':
        return Colors.green;
      case 'mastered':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'known':
        return '已认识';
      case 'mastered':
        return '已掌握';
      default:
        return '学习中';
    }
  }
}
