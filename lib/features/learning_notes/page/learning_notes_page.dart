import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:zephyr_reader/features/learning_notes/application/learning_notes_view_model.dart';
import 'package:zephyr_reader/features/learning_notes/application/models/note_with_book.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class LearningNotesPage extends HookWidget {
  final LearningNotesViewModel vm;

  const LearningNotesPage({super.key, required this.vm});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Load on mount
    useEffect(() {
      vm.initialize();
      return null;
    }, []);

    // Bind VM signals
    final loading = useSignalValue<bool, Signal<bool>>(vm.loading);
    final vocabList = useSignalValue<List<Vocab>, Signal<List<Vocab>>>(vm.vocabList);
    final noteList = useSignalValue<List<NoteWithBook>, Signal<List<NoteWithBook>>>(vm.noteList);
    final vocabTotalCount = useSignalValue<int, Signal<int>>(vm.vocabTotalCount);
    final noteTotalCount = useSignalValue<int, Signal<int>>(vm.noteTotalCount);
    final vocabMasteredCount = useSignalValue<int, Signal<int>>(vm.vocabMasteredCount);
    final activeTab = useSignalValue<int, Signal<int>>(vm.activeTab);
    final vocabFilterStatus = useSignalValue<VocabStatus?, Signal<VocabStatus?>>(vm.vocabFilterStatus);
    final vocabFilterWordList = useSignalValue<String?, Signal<String?>>(vm.vocabFilterWordList);
    final noteLoading = useSignalValue<bool, Signal<bool>>(vm.noteLoading);
    final noteFilterBookId = useSignalValue<String?, Signal<String?>>(vm.noteFilterBookId);
    final bookTitles = useSignalValue<Map<String, String>, Signal<Map<String, String>>>(vm.bookTitles);

    if (loading && vocabList.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('学习与笔记', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          centerTitle: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('学习与笔记', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
                actions: [_buildExportButton(context, cs)],
      ),
      body: Column(
        children: [
          _buildStatsDashboard(cs, vocabTotalCount, noteTotalCount, vocabMasteredCount),
          _buildTabSwitcher(cs, activeTab, vocabTotalCount, noteTotalCount),
          Expanded(
            child: activeTab == 0
                ? _buildVocabContent(context, cs, vocabList, vocabFilterStatus, vocabFilterWordList, bookTitles)
                : _buildNoteContent(context, cs, noteList, noteLoading, noteFilterBookId, bookTitles),
          ),
        ],
      ),
    );
  }

  // ==================== Export Button ====================

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
                Text('导出', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('导出学习数据', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              _exportOption(cs, PhosphorIconsRegular.fileText, '生词表 (CSV)', '导出所有生词为表格文件', () {}),
              const SizedBox(height: 8),
              _exportOption(cs, PhosphorIconsRegular.markdownLogo, '笔记 (Markdown)', '导出所有笔记为 Markdown 文档', () {}),
            ],
          ),
        ),
      ),
    );
  }

  Widget _exportOption(ColorScheme cs, IconData icon, String title, String subtitle, VoidCallback onTap) {
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
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(PhosphorIconsRegular.caretRight, size: 16, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== Stats Dashboard ====================

  Widget _buildStatsDashboard(ColorScheme cs, int vocabTotalCount, int noteTotalCount, int vocabMasteredCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Row(
        children: [
          _statCard(cs, '$vocabTotalCount', '生词总数', PhosphorIconsRegular.bookOpen, const Color(0xFFAB47BC), const Color(0xFFF3E5F5)),
          const SizedBox(width: 10),
          _statCard(cs, '$noteTotalCount', '笔记条数', PhosphorIconsRegular.notePencil, const Color(0xFFFFA726), const Color(0xFFFFF3E0)),
          const SizedBox(width: 10),
          _statCard(cs, '$vocabMasteredCount', '已掌握', PhosphorIconsRegular.sealCheck, const Color(0xFF66BB6A), const Color(0xFFE8F5E9)),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.04, end: 0);
  }

  Widget _statCard(ColorScheme cs, String number, String label, IconData icon, Color accent, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2), width: 0.5),
        ),
        child: Column(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 14, color: accent),
            ),
            const SizedBox(height: 8),
            Text(number, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: cs.onSurface)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  // ==================== Tab Switcher ====================

  Widget _buildTabSwitcher(ColorScheme cs, int activeTab, int vocabCount, int noteCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(3),
        child: Row(
          children: [
            _tabItem(cs, 0, '生词本', vocabCount, activeTab),
            const SizedBox(width: 3),
            _tabItem(cs, 1, '笔记本', noteCount, activeTab),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideY(begin: -0.03, end: 0);
  }

  Widget _tabItem(ColorScheme cs, int index, String label, int count, int activeTab) {
    final active = activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => vm.switchTab(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? cs.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active ? [BoxShadow(color: cs.onSurface.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1))] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w600 : FontWeight.w500, color: active ? cs.onSurface : cs.onSurfaceVariant)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: active ? cs.primary.withValues(alpha: 0.1) : cs.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: active ? cs.primary : cs.onSurfaceVariant)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== Vocabulary Tab ====================

  Widget _buildVocabContent(
    BuildContext context, ColorScheme cs, List<Vocab> vocabList,
    VocabStatus? filterStatus, String? filterWordList,
    Map<String, String> bookTitles,
  ) {
    return Column(
      children: [
        _buildVocabFilters(cs, filterStatus, filterWordList),
        Expanded(child: _buildVocabList(context, cs, vocabList, bookTitles)),
      ],
    );
  }

  Widget _buildVocabFilters(ColorScheme cs, VocabStatus? filterStatus, String? filterWordList) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _vocabFilterChip('全部', null, selected: filterStatus == null, cs: cs, onTap: () => vm.setVocabFilterStatus(null)),
              const SizedBox(width: 8),
              _vocabFilterChip('未学', VocabStatus.new_, selected: filterStatus == VocabStatus.new_, cs: cs, onTap: () => vm.setVocabFilterStatus(VocabStatus.new_)),
              const SizedBox(width: 8),
              _vocabFilterChip('学习中', VocabStatus.learning, selected: filterStatus == VocabStatus.learning, cs: cs, onTap: () => vm.setVocabFilterStatus(VocabStatus.learning)),
              const SizedBox(width: 8),
              _vocabFilterChip('已掌握', VocabStatus.mastered, selected: filterStatus == VocabStatus.mastered, cs: cs, onTap: () => vm.setVocabFilterStatus(VocabStatus.mastered)),
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
              _wordListChip('全部词库', null, selected: filterWordList == null, cs: cs, onTap: () => vm.setVocabFilterWordList(null)),
              const SizedBox(width: 6),
              _wordListChip('CET-4', 'CET-4', selected: filterWordList == 'CET-4', cs: cs, onTap: () => vm.setVocabFilterWordList('CET-4')),
              const SizedBox(width: 6),
              _wordListChip('CET-6', 'CET-6', selected: filterWordList == 'CET-6', cs: cs, onTap: () => vm.setVocabFilterWordList('CET-6')),
              const SizedBox(width: 6),
              _wordListChip('IELTS', 'IELTS', selected: filterWordList == 'IELTS', cs: cs, onTap: () => vm.setVocabFilterWordList('IELTS')),
              const SizedBox(width: 6),
              _wordListChip('TOEFL', 'TOEFL', selected: filterWordList == 'TOEFL', cs: cs, onTap: () => vm.setVocabFilterWordList('TOEFL')),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _vocabFilterChip(String label, VocabStatus? status, {required bool selected, required ColorScheme cs, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? cs.primary.withValues(alpha: 0.1) : cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? cs.primary : cs.outlineVariant.withValues(alpha: 0.3), width: 1),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w500, color: selected ? cs.primary : cs.onSurfaceVariant)),
      ),
    );
  }

  Widget _wordListChip(String label, String? wordList, {required bool selected, required ColorScheme cs, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? cs.secondary.withValues(alpha: 0.1) : cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? cs.secondary : cs.outlineVariant.withValues(alpha: 0.2), width: 1),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w600 : FontWeight.w500, color: selected ? cs.secondary : cs.onSurfaceVariant)),
      ),
    );
  }

  Widget _buildVocabList(BuildContext context, ColorScheme cs, List<Vocab> vocabList, Map<String, String> bookTitles) {
    if (vocabList.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIconsRegular.bookOpen, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('暂无生词', style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text('在阅读中添加生词后，它们会出现在这里', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant.withValues(alpha: 0.6))),
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
      itemBuilder: (_, i) => _buildVocabItem(cs, vocabList[i], i, bookTitles),
    );
  }

  Widget _buildVocabItem(ColorScheme cs, Vocab item, int index, Map<String, String> bookTitles) {
    final statusColor = _vocabStatusColor(item.status, cs);
    final statusLabel = _vocabStatusLabel(item.status);
    final bookTitle = bookTitles[item.bookId];
    final animDelay = (50 * index.clamp(0, 10)).ms;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 6, left: 4, right: 12), decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(item.word, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface)),
                      if (item.pinyin.isNotEmpty) ...[const SizedBox(width: 8), Text('/${item.pinyin}/', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant))],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(item.translation, style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.7))),
                  if (bookTitle != null || item.wordList != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (bookTitle != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text('📖 $bookTitle', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: cs.primary.withValues(alpha: 0.8))),
                          ),
                        if (item.wordList != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: cs.secondary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                            child: Text(item.wordList!, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: cs.secondary)),
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
                if (item.status != VocabStatus.new_) const PopupMenuItem(value: VocabStatus.new_, child: Text('未学')),
                if (item.status != VocabStatus.learning) const PopupMenuItem(value: VocabStatus.learning, child: Text('学习中')),
                if (item.status != VocabStatus.mastered) const PopupMenuItem(value: VocabStatus.mastered, child: Text('已掌握')),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms, delay: animDelay);
  }

  Color _vocabStatusColor(VocabStatus status, ColorScheme cs) {
    switch (status) {
      case VocabStatus.mastered: return const Color(0xFF66BB6A);
      case VocabStatus.learning: return const Color(0xFFFFA726);
      case VocabStatus.ignored: return cs.onSurfaceVariant;
      default: return cs.onSurface;
    }
  }

  String _vocabStatusLabel(VocabStatus status) {
    switch (status) {
      case VocabStatus.mastered: return '已掌握';
      case VocabStatus.learning: return '学习中';
      case VocabStatus.ignored: return '已忽略';
      default: return '未学';
    }
  }

  // ==================== Notes Tab ====================

  Widget _buildNoteContent(
    BuildContext context, ColorScheme cs, List<NoteWithBook> noteList, bool noteLoading,
    String? filterBookId, Map<String, String> bookTitles,
  ) {
    if (noteLoading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        _buildNoteFilters(cs, filterBookId, bookTitles),
        Expanded(child: _buildNoteList(context, cs, noteList)),
      ],
    );
  }

  Widget _buildNoteFilters(ColorScheme cs, String? filterBookId, Map<String, String> bookTitles) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _noteFilterChip('全部书籍', null, selected: filterBookId == null, cs: cs, onTap: () => vm.setNoteFilterBook(null)),
          for (final entry in bookTitles.entries)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _noteFilterChip(entry.value, entry.key, selected: filterBookId == entry.key, cs: cs, onTap: () => vm.setNoteFilterBook(entry.key)),
            ),
        ],
      ),
    );
  }

  Widget _noteFilterChip(String label, String? bookId, {required bool selected, required ColorScheme cs, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFA726).withValues(alpha: 0.12) : cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? const Color(0xFFFFA726) : cs.outlineVariant.withValues(alpha: 0.3), width: 1),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w600 : FontWeight.w500, color: selected ? const Color(0xFFFFA726) : cs.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _buildNoteList(BuildContext context, ColorScheme cs, List<NoteWithBook> noteList) {
    if (noteList.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIconsRegular.notePencil, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('暂无笔记', style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text('在阅读中做笔记后，它们会出现在这里', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant.withValues(alpha: 0.6))),
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
      itemCount: noteList.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _buildNoteItem(cs, noteList[i], i),
    );
  }

  Widget _buildNoteItem(ColorScheme cs, NoteWithBook item, int index) {
    final note = item.note;
    final animDelay = (50 * index.clamp(0, 10)).ms;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: const BorderSide(color: Color(0xFFFFA726), width: 3),
          right: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2), width: 0.5),
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2), width: 0.5),
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2), width: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (note.selectedText != null && note.selectedText!.isNotEmpty) ...[
              Text(note.selectedText!, style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: cs.onSurfaceVariant, height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
            ],
            Text(note.content, style: TextStyle(fontSize: 14, color: cs.onSurface, height: 1.5)),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(note.noteType == NoteType.highlight ? PhosphorIconsRegular.highlighter : PhosphorIconsRegular.pencilSimpleLine, size: 12, color: cs.primary.withValues(alpha: 0.7)),
                const SizedBox(width: 4),
                Text(item.bookTitle, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.primary.withValues(alpha: 0.8))),
                const Spacer(),
                Text(_formatDate(note.createdAt), style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant.withValues(alpha: 0.6))),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms, delay: animDelay);
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}
