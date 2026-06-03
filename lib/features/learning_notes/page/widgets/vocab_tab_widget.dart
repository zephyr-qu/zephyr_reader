import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:zephyr_reader/core/presentation/widgets/selection_chip.dart';
import 'package:zephyr_reader/features/learning_notes/application/learning_notes_view_model.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/src/rust/storage/vocab_status_extension.dart';

class LearningNotesVocabTab extends StatelessWidget {
  final ColorScheme colorScheme;
  final List<Vocab> vocabList;
  final VocabStatus? filterStatus;
  final String? filterWordList;
  final Map<String, String> bookTitles;
  final LearningNotesViewModel vm;

  const LearningNotesVocabTab({
    super.key,
    required this.colorScheme,
    required this.vocabList,
    required this.filterStatus,
    required this.filterWordList,
    required this.bookTitles,
    required this.vm,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildVocabFilters(),
        Expanded(child: _buildVocabList(context)),
      ],
    );
  }

  Widget _buildVocabFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _vocabFilterChip(
                '全部',
                null,
                selected: filterStatus == null,
                onTap: () => vm.setVocabFilterStatus(null),
              ),
              const SizedBox(width: 8),
              _vocabFilterChip(
                '未学',
                VocabStatus.new_,
                selected: filterStatus == VocabStatus.new_,
                onTap: () => vm.setVocabFilterStatus(VocabStatus.new_),
              ),
              const SizedBox(width: 8),
              _vocabFilterChip(
                '学习中',
                VocabStatus.learning,
                selected: filterStatus == VocabStatus.learning,
                onTap: () => vm.setVocabFilterStatus(VocabStatus.learning),
              ),
              const SizedBox(width: 8),
              _vocabFilterChip(
                '已掌握',
                VocabStatus.mastered,
                selected: filterStatus == VocabStatus.mastered,
                onTap: () => vm.setVocabFilterStatus(VocabStatus.mastered),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _wordListChip(
                '全部词库',
                null,
                selected: filterWordList == null,
                onTap: () => vm.setVocabFilterWordList(null),
              ),
              const SizedBox(width: 6),
              _wordListChip(
                'CET-4',
                'CET-4',
                selected: filterWordList == 'CET-4',
                onTap: () => vm.setVocabFilterWordList('CET-4'),
              ),
              const SizedBox(width: 6),
              _wordListChip(
                'CET-6',
                'CET-6',
                selected: filterWordList == 'CET-6',
                onTap: () => vm.setVocabFilterWordList('CET-6'),
              ),
              const SizedBox(width: 6),
              _wordListChip(
                'IELTS',
                'IELTS',
                selected: filterWordList == 'IELTS',
                onTap: () => vm.setVocabFilterWordList('IELTS'),
              ),
              const SizedBox(width: 6),
              _wordListChip(
                'TOEFL',
                'TOEFL',
                selected: filterWordList == 'TOEFL',
                onTap: () => vm.setVocabFilterWordList('TOEFL'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _vocabFilterChip(
    String label,
    VocabStatus? status, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return SelectionChip(
      label: label,
      selected: selected,
      colorScheme: colorScheme,
      onTap: onTap,
    );
  }

  Widget _wordListChip(
    String label,
    String? wordList, {
    required bool selected,
    required VoidCallback onTap,
  }) {
    return SelectionChip(
      label: label,
      selected: selected,
      colorScheme: colorScheme,
      onTap: onTap,
      activeColor: colorScheme.secondary,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      fontSize: 11,
      borderRadius: 14,
    );
  }

  Widget _buildVocabList(BuildContext context) {
    final cs = colorScheme;
    if (vocabList.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIconsRegular.bookOpen,
              size: 48,
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              '暂无生词',
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              '在阅读中添加生词后，它们会出现在这里',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => context.push('/bookshelf'),
              icon: const Icon(PhosphorIconsRegular.books, size: 16),
              label: const Text('去阅读'),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: vocabList.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _buildVocabItem(cs, vocabList[i], i),
    );
  }

  Widget _buildVocabItem(ColorScheme cs, Vocab item, int index) {
    final statusColor = _vocabStatusColor(item.status, cs);
    final statusLabel = _vocabStatusLabel(item.status);
    final bookTitle = bookTitles[item.bookId];
    final animDelay = (50 * index.clamp(0, 10)).ms;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6, left: 4, right: 12),
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        item.word,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      if (item.pinyin.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          '/${item.pinyin}/',
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.translation,
                    style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  if (bookTitle != null || item.wordList != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (bookTitle != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              '📖 $bookTitle',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: cs.primary.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        if (item.wordList != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: cs.secondary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.wordList!,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: cs.secondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<VocabStatus>(
              initialValue: item.status,
              onSelected: (s) => vm.updateVocabStatus(item.id, s),
              itemBuilder: (_) => [
                if (item.status != VocabStatus.new_)
                  const PopupMenuItem(
                    value: VocabStatus.new_,
                    child: Text('未学'),
                  ),
                if (item.status != VocabStatus.learning)
                  const PopupMenuItem(
                    value: VocabStatus.learning,
                    child: Text('学习中'),
                  ),
                if (item.status != VocabStatus.mastered)
                  const PopupMenuItem(
                    value: VocabStatus.mastered,
                    child: Text('已掌握'),
                  ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms, delay: animDelay);
  }

  Color _vocabStatusColor(VocabStatus status, ColorScheme cs) {
    // Use shared extension for mastered/learning/ignored, fallback to theme for new_
    if (status == VocabStatus.new_) return cs.onSurface;
    return status.color;
  }

  String _vocabStatusLabel(VocabStatus status) => status.displayName;
}
