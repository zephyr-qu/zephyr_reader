import 'package:zephyr_reader/src/rust/domain/vocabulary/models.dart';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/features/vocabulary/application/vocabulary_view_model.dart';
import 'package:zephyr_reader/features/vocabulary/page/widgets/vocab_word_list_view.dart';
import 'package:zephyr_reader/features/vocabulary/page/widgets/vocab_stats_row.dart';

import 'package:zephyr_reader/l10n/app_localizations.dart';

/// 生词本页面。
///
/// 展示已标记的生词列表，支持按学习状态筛选和查看单词详情。
/// 使用 [VocabularyViewModel] 加载单词数据。
class VocabularyPage extends HookWidget {
  const VocabularyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final VocabularyViewModel vm = useMemoized(() => VocabularyViewModel());
    final l10n = AppLocalizations.of(context)!;

    // 筛选状态 → 页面局部信号（P1 迁移）
    final filterStatus = useSignal<VocabStatus?>(VocabStatus.unstarted);
    final filterWordList = useSignal<String?>(null);

    // 筛选变更 → 立即重新加载
    void onFilterChanged(VocabStatus? status) {
      filterStatus.value = status;
      vm.loadWords(status: status, wordList: filterWordList.value);
    }

    void onWordListFilterChanged(String? wordList) {
      filterWordList.value = wordList;
      vm.loadWords(status: filterStatus.value, wordList: wordList);
    }

    // Load on mount
    useEffect(() {
      vm.loadWords(status: filterStatus.value, wordList: filterWordList.value);
      return () => vm.dispose();
    }, []);

    final AsyncState<VocabStats?> stats = useSignalValue(vm.stats);
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
          tooltip: l10n.back,
        ),
        title: Text(l10n.vocabularyBook),
        actions: [
          IconButton(
            icon: const Icon(PhosphorIconsRegular.arrowsClockwise),
            onPressed: () => vm.refresh(
              status: filterStatus.value,
              wordList: filterWordList.value,
            ),
            tooltip: l10n.refresh,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            VocabStatsRow(
              stats: stats,
              filterStatus: filterStatus.value,
              filterWordList: filterWordList.value,
              wordLists: wordListNames.value ?? [],
              onFilterChanged: onFilterChanged,
              onWordListFilterChanged: onWordListFilterChanged,
            ),
            Expanded(
              child: VocabWordListView(
                words: wordsState,
                bookTitles: bookTitles.value ?? {},
                onRetry: () => vm.loadWords(
                  status: filterStatus.value,
                  wordList: filterWordList.value,
                ),
                onDeleteWord: (id) => vm.deleteWord(
                  id,
                  currentFilter: filterStatus.value,
                  currentWordList: filterWordList.value,
                ),
                onUpdateStatus: (id, s) => vm.updateStatus(
                  id,
                  s,
                  currentFilter: filterStatus.value,
                  currentWordList: filterWordList.value,
                ),
                hasWords: hasAnyWords,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
