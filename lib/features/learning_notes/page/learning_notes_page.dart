import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:zephyr_reader/features/learning_notes/application/learning_notes_view_model.dart';
import 'package:zephyr_reader/features/learning_notes/application/models/note_with_book.dart';
import 'package:zephyr_reader/features/learning_notes/page/widgets/note_tab_widget.dart';
import 'package:zephyr_reader/features/learning_notes/page/widgets/stat_dashboard_widget.dart';
import 'package:zephyr_reader/features/learning_notes/page/widgets/tab_switcher_widget.dart';
import 'package:zephyr_reader/features/learning_notes/page/widgets/vocab_tab_widget.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class LearningNotesPage extends HookWidget {
  final LearningNotesViewModel vm;

  const LearningNotesPage({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    useEffect(() {
      vm.initialize();
      return null;
    }, []);

    final loading = useSignalValue<bool, Signal<bool>>(vm.loading);
    final vocabList = useSignalValue<List<Vocab>, Signal<List<Vocab>>>(
      vm.vocabList,
    );
    final noteList =
        useSignalValue<List<NoteWithBook>, Signal<List<NoteWithBook>>>(
          vm.noteList,
        );
    final vocabTotalCount = useSignalValue<int, Signal<int>>(
      vm.vocabTotalCount,
    );
    final noteTotalCount = useSignalValue<int, Signal<int>>(vm.noteTotalCount);
    final vocabMasteredCount = useSignalValue<int, Signal<int>>(
      vm.vocabMasteredCount,
    );
    final activeTab = useSignalValue<int, Signal<int>>(vm.activeTab);
    final vocabFilterStatus =
        useSignalValue<VocabStatus?, Signal<VocabStatus?>>(
          vm.vocabFilterStatus,
        );
    final vocabFilterWordList = useSignalValue<String?, Signal<String?>>(
      vm.vocabFilterWordList,
    );
    final noteLoading = useSignalValue<bool, Signal<bool>>(vm.noteLoading);
    final noteFilterBookId = useSignalValue<String?, Signal<String?>>(
      vm.noteFilterBookId,
    );
    final bookTitles =
        useSignalValue<Map<String, String>, Signal<Map<String, String>>>(
          vm.bookTitles,
        );

    if (loading && vocabList.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            '学习与笔记',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          '学习与笔记',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        actions: [_buildExportButton(context, cs)],
      ),
      body: Column(
        children: [
          LearningNotesStatDashboard(
            colorScheme: cs,
            vocabTotalCount: vocabTotalCount,
            noteTotalCount: noteTotalCount,
            vocabMasteredCount: vocabMasteredCount,
          ),
          LearningNotesTabSwitcher(
            colorScheme: cs,
            activeTab: activeTab,
            vocabCount: vocabTotalCount,
            noteCount: noteTotalCount,
            vm: vm,
          ),
          Expanded(
            child: activeTab == 0
                ? LearningNotesVocabTab(
                    colorScheme: cs,
                    vocabList: vocabList,
                    filterStatus: vocabFilterStatus,
                    filterWordList: vocabFilterWordList,
                    bookTitles: bookTitles,
                    vm: vm,
                  )
                : LearningNotesNoteTab(
                    colorScheme: cs,
                    noteList: noteList,
                    noteLoading: noteLoading,
                    filterBookId: noteFilterBookId,
                    bookTitles: bookTitles,
                    vm: vm,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportButton(BuildContext context, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Material(
        color: cs.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showExportMenu(context, cs),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(PhosphorIconsRegular.export, size: 14),
                SizedBox(width: 4),
                Text(
                  '导出',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showExportMenu(BuildContext context, ColorScheme cs) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '导出学习数据',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              _exportOption(
                cs,
                PhosphorIconsRegular.fileText,
                '生词表 (CSV)',
                '导出所有生词为表格文件',
                () {},
              ),
              const SizedBox(height: 8),
              _exportOption(
                cs,
                PhosphorIconsRegular.markdownLogo,
                '笔记 (Markdown)',
                '导出所有笔记为 Markdown 文档',
                () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _exportOption(
    ColorScheme cs,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                PhosphorIconsRegular.caretRight,
                size: 16,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
