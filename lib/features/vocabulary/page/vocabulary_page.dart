import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/features/vocabulary/application/vocabulary_view_model.dart';
import 'package:zephyr_reader/features/vocabulary/page/widgets/vocab_word_list_view.dart';
import 'package:zephyr_reader/features/vocabulary/page/widgets/vocab_stats_row.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class VocabularyPage extends HookWidget {
  const VocabularyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final VocabularyViewModel vm = useMemoized(() => VocabularyViewModel());

    // Load on mount
    useEffect(() {
      vm.loadWords();
      return () => vm.dispose();
    }, []);

    final AsyncState<VocabStats?> stats = useSignalValue(vm.stats);
    final VocabStatus? filterStatus = useSignalValue(vm.filterStatus);
    final String? filterWordList = useSignalValue(vm.filterWordList);
    final AsyncState<List<Vocab>> wordsState = useSignalValue(vm.words);
    final AsyncState<Map<String, String>> bookTitles = useSignalValue(
      vm.bookTitles,
    );
    final hasAnyWords = (() {
      final s = stats.value;
      if (s == null) return false;
      return (s.unstartedCount +
              s.learningCount +
              s.masteredCount +
              s.ignoredCount) >
          0;
    })();
    final AsyncState<List<String>> wordListNames = useSignalValue(vm.wordLists);

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
              stats: stats,
              filterStatus: filterStatus,
              filterWordList: filterWordList,
              wordLists: wordListNames.value ?? [],
              onFilterChanged: vm.setFilter,
              onWordListFilterChanged: vm.setWordListFilter,
            ),
            Expanded(
              child: VocabWordListView(
                words: wordsState,
                bookTitles: bookTitles.value ?? {},
                vm: vm,
                hasWords: hasAnyWords,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
