library;

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/features/vocabulary/application/vocabulary_view_model.dart';

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
        title: const Text('生词本'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _vm.refresh(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsRow(theme),
          _buildFilterRow(),
          Expanded(child: _buildWordList(theme)),
        ],
      ),
    );
  }

  Widget _buildStatsRow(ThemeData theme) {
    return Watch.builder(builder: (context) {
      final s = _vm.stats.value;
      if (s == null) return const SizedBox(height: 8);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            _statChip('全部', s.totalWords, theme),
            const SizedBox(width: 12),
            _statChip('学习中', s.learningCount, theme),
            const SizedBox(width: 12),
            _statChip('已掌握', s.knownCount + s.masteredCount, theme),
          ],
        ),
      );
    });
  }

  Widget _statChip(String label, int count, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text('$label $count',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildFilterRow() {
    const filters = <String?, String>{
      null: '全部',
      'learning': '学习中',
      'known': '已认识',
      'mastered': '已掌握',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.entries.map((e) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Watch.builder(builder: (context) {
                final selected = _vm.filterStatus.value == e.key;
                return FilterChip(
                  label: Text(e.value, style: const TextStyle(fontSize: 13)),
                  selected: selected,
                  onSelected: (_) {
                    _vm.setFilter(e.key);
                  },
                );
              }),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildWordList(ThemeData theme) {
    return Watch.builder(builder: (context) {
      if (_vm.loading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      final items = _vm.words.value;
      if (items.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bookmark_border, size: 48,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 12),
              const Text('暂无生词', style: TextStyle(color: DesignTokens.textSecondary)),
            ],
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = items[index];
          return Dismissible(
            key: ValueKey(item.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: Colors.red,
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (_) => _vm.deleteWord(item.id),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              title: Text(item.word,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              subtitle: item.pinyin.isNotEmpty
                  ? Text(item.pinyin,
                      style: const TextStyle(fontSize: 12, color: Colors.grey))
                  : null,
              trailing: PopupMenuButton<String>(
                initialValue: item.status,
                onSelected: (s) => _vm.updateStatus(item.id, s),
                itemBuilder: (_) => [
                  if (item.status != 'learning')
                    const PopupMenuItem(value: 'learning', child: Text('学习中')),
                  if (item.status != 'known')
                    const PopupMenuItem(value: 'known', child: Text('已认识')),
                  if (item.status != 'mastered')
                    const PopupMenuItem(value: 'mastered', child: Text('已掌握')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor(item.status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusLabel(item.status),
                    style: TextStyle(fontSize: 11, color: _statusColor(item.status)),
                  ),
                ),
              ),
            ),
          );
        },
      );
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'known': return Colors.green;
      case 'mastered': return Colors.blue;
      default: return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'known': return '已认识';
      case 'mastered': return '已掌握';
      default: return '学习中';
    }
  }
}
