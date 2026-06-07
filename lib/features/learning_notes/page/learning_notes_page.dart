import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/routing/route_constants.dart';
import 'package:zephyr_reader/features/learning_notes/application/learning_notes_view_model.dart';
import 'package:zephyr_reader/features/learning_notes/page/widgets/note_tab_widget.dart';
import 'package:zephyr_reader/features/learning_notes/page/widgets/stat_dashboard_widget.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 学习笔记页面。
///
/// 展示笔记/高亮列表，支持按来源书籍筛选和查看笔记详情。
/// 使用 [LearningNotesViewModel] 加载笔记数据。
class LearningNotesPage extends HookWidget {
  const LearningNotesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = useMemoized(() => LearningNotesViewModel());
    final l10n = AppLocalizations.of(context)!;

    useEffect(() {
      vm.loadAll();
      return null;
    }, []);

    final AsyncState<List<NoteWithBook>> noteList = useSignalValue(vm.noteList);
    final AsyncState<int> noteTotalCount = useSignalValue(vm.noteTotalCount);
    final String? noteFilterBookId = useSignalValue(vm.noteFilterBookId);
    final AsyncState<Map<String, String>> filterBookTitles = useSignalValue(
      vm.filterBookTitles,
    );

    const titleStyle = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
    );

    return noteList.map(
      data: (List<NoteWithBook> noteList) => Scaffold(
        appBar: AppBar(
          title: Text(l10n.selectionNote, style: titleStyle),
          actions: [
            IconButton(
              icon: const Icon(PhosphorIconsRegular.bookOpen),
              tooltip: l10n.vocabulary,
              onPressed: () => context.push(RoutePaths.vocabulary),
            ),
          ],
        ),
        body: Column(
          children: [
            LearningNotesStatDashboard(
              noteTotalCount: noteTotalCount.value ?? 0,
            ),
            Expanded(
              child: LearningNotesNoteTab(
                noteList: noteList,
                filterBookId: noteFilterBookId,
                bookTitles: filterBookTitles.value ?? {},
                onNoteFilterChanged: vm.setNoteFilterBook,
              ),
            ),
          ],
        ),
      ),
      error: () {},
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.selectionNote, style: titleStyle)),
        body: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
