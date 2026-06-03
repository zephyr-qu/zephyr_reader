

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/presentation/widgets/empty_state_widget.dart';
import 'package:zephyr_reader/core/presentation/widgets/selection_chip.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/vocabulary/application/vocabulary_view_model.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/src/rust/storage/vocab_status_extension.dart';

class VocabularyPage extends HookWidget {
  late final VocabularyViewModel vm = getIt<VocabularyViewModel>();

  VocabularyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Load on mount
    useEffect(() {
      vm.loadWords();
      return null;
    }, []);

    // Bind VM signals
    final stats = useSignalValue<VocabStats?, Signal<VocabStats?>>(vm.stats);
    final filterStatus = useSignalValue<VocabStatus?, Signal<VocabStatus?>>(
      vm.filterStatus,
    );
    final filterWordList = useSignalValue<String?, Signal<String?>>(
      vm.filterWordList,
    );
    final wordsState =
        useSignalValue<AsyncState<List<Vocab>>, AsyncSignal<List<Vocab>>>(
          vm.words,
        );
    final bookTitles =
        useSignalValue<Map<String, String>, Signal<Map<String, String>>>(
          vm.bookTitles,
        );

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
            onPressed: () => vm.refresh(),
            tooltip: '刷新',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildStatsRow(theme, stats, filterStatus, filterWordList),
            Expanded(child: _buildWordList(theme, wordsState, bookTitles)),
          ],
        ),
      ),
    );
  }

  static const wordLists = ['CET-4', 'CET-6', 'IELTS', 'TOEFL'];

  Widget _buildStatsRow(
    ThemeData theme,
    VocabStats? stats,
    VocabStatus? filterStatus,
    String? filterWordList,
  ) {
    if (stats == null) {
      return SizedBox(height: DesignTokens.spacing(Spacing.sm));
    }
    final notStartedCount =
        stats.totalWords -
        stats.learningCount -
        stats.knownCount -
        stats.masteredCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip(
                  '全部',
                  stats.totalWords.toString(),
                  filterStatus: null,
                  selected: filterStatus == null,
                  theme: theme,
                ),
                const SizedBox(width: 8),
                _filterChip(
                  '未学',
                  notStartedCount.toString(),
                  filterStatus: VocabStatus.new_,
                  selected: filterStatus == VocabStatus.new_,
                  theme: theme,
                ),
                const SizedBox(width: 8),
                _filterChip(
                  '学习中',
                  stats.learningCount.toString(),
                  filterStatus: VocabStatus.learning,
                  selected: filterStatus == VocabStatus.learning,
                  theme: theme,
                ),
                const SizedBox(width: 8),
                _filterChip(
                  '已忽略',
                  stats.knownCount.toString(),
                  filterStatus: VocabStatus.ignored,
                  selected: filterStatus == VocabStatus.ignored,
                  theme: theme,
                ),
                const SizedBox(width: 8),
                _filterChip(
                  '已掌握',
                  stats.masteredCount.toString(),
                  filterStatus: VocabStatus.mastered,
                  selected: filterStatus == VocabStatus.mastered,
                  theme: theme,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip(
                  '全部词库',
                  '',
                  wordList: null,
                  selected: filterWordList == null,
                  theme: theme,
                  isWordList: true,
                ),
                const SizedBox(width: 8),
                for (final wl in wordLists)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _filterChip(
                      wl,
                      '',
                      wordList: wl,
                      selected: filterWordList == wl,
                      theme: theme,
                      isWordList: true,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _filterChip(
    String label,
    String count, {
    VocabStatus? filterStatus,
    String? wordList,
    required bool selected,
    required ThemeData theme,
    bool isWordList = false,
  }) {
    final cs = theme.colorScheme;
    if (isWordList) {
      return SelectionChip(
        label: '$label $count',
        selected: selected,
        colorScheme: cs,
        onTap: () => vm.setWordListFilter(wordList),
        activeColor: cs.secondary,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        inactiveBgColor: cs.surfaceContainerHighest,
      );
    }
    return SelectionChip(
      label: '$label $count',
      selected: selected,
      colorScheme: cs,
      onTap: () => vm.setFilter(filterStatus),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      inactiveBgColor: cs.surfaceContainerHighest,
    );
  }

  Widget _buildWordList(
    ThemeData theme,
    AsyncState<List<Vocab>> wordsState,
    Map<String, String> bookTitles,
  ) {
    if (wordsState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final err = wordsState.error;
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
              err.toString(),
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: DesignTokens.spacing(Spacing.md)),
            FilledButton.tonal(
              onPressed: () => vm.loadWords(),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    final items = wordsState.value ?? [];
    if (items.isEmpty) {
      return EmptyStateWidget(
        icon: PhosphorIconsRegular.bookmarkSimple,
        title: '暂无生词',
        iconSize: 48,
        colorScheme: theme.colorScheme,
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
            onDismissed: (_) => vm.deleteWord(item.id),
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
              subtitle: _buildSubtitle(item, bookTitles),
              trailing: PopupMenuButton<String>(
                initialValue: switch (item.status) {
                  VocabStatus.new_ => 'new',
                  VocabStatus.learning => 'learning',
                  VocabStatus.mastered => 'mastered',
                  VocabStatus.ignored => 'ignored',
                },
                onSelected: (s) => vm.updateStatus(item.id, s),
                itemBuilder: (_) => [
                  if (item.status != VocabStatus.new_)
                    const PopupMenuItem(value: 'new', child: Text('未学')),
                  if (item.status != VocabStatus.learning)
                    const PopupMenuItem(value: 'learning', child: Text('学习中')),
                  if (item.status != VocabStatus.mastered)
                    const PopupMenuItem(value: 'mastered', child: Text('已掌握')),
                  if (item.status != VocabStatus.ignored)
                    const PopupMenuItem(value: 'ignored', child: Text('已忽略')),
                ],
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: DesignTokens.spacing(Spacing.sm),
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(item.status).withValues(alpha: 0.15),
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
  }

  Widget? _buildSubtitle(Vocab item, Map<String, String> bookTitles) {
    final parts = <String>[];
    if (item.pinyin.isNotEmpty) {
      parts.add(item.pinyin);
    }
    if (item.bookId != null && item.bookId!.isNotEmpty) {
      final title = bookTitles[item.bookId];
      if (title != null && title.isNotEmpty) {
        parts.add('来自《$title》');
      }
    }
    if (parts.isEmpty) return null;
    return Text(
      parts.join(' · '),
      style: const TextStyle(fontSize: 12, color: Colors.grey),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Color _statusColor(VocabStatus status) => status.color;

  String _statusLabel(VocabStatus status) => status.displayName;
}
