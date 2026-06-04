import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/presentation/widgets/empty_state_widget.dart';
import 'package:zephyr_reader/core/utils/app_error_mapper.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/features/vocabulary/application/vocabulary_view_model.dart';
import 'package:zephyr_reader/features/vocabulary/page/widgets/vocab_list_item_tile.dart';
import 'package:zephyr_reader/features/vocabulary/page/widgets/vocab_stats_row.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class VocabularyPage extends HookWidget {
  const VocabularyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final VocabularyViewModel vm = useMemoized(() => VocabularyViewModel());
    final theme = Theme.of(context);

    // Load on mount
    useEffect(() {
      vm.loadWords();
      return () => vm.dispose();
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
            VocabStatsRow(
              theme: theme,
              stats: stats,
              filterStatus: filterStatus,
              filterWordList: filterWordList,
              wordLists: wordLists,
              onFilterChanged: vm.setFilter,
              onWordListFilterChanged: vm.setWordListFilter,
            ),
            Expanded(child: _buildWordList(theme, wordsState, bookTitles, vm)),
          ],
        ),
      ),
    );
  }
 
  static const wordLists = ['CET-4', 'CET-6', 'IELTS', 'TOEFL'];


  Widget _buildWordList(
    ThemeData theme,
    AsyncState<List<Vocab>> wordsState,
    Map<String, String> bookTitles,
    VocabularyViewModel vm,
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
              AppErrorMapper.humanReadable(err),
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
        return VocabListItemTile(
          item: item,
          bookTitles: bookTitles,
          theme: theme,
          onDismissed: () => vm.deleteWord(item.id),
          onUpdateStatus: (s) => vm.updateStatus(item.id, s),
        );
      },
    );
  }

}
