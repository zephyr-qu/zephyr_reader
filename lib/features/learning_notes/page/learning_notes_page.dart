
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/features/learning_notes/application/learning_notes_view_model.dart';
import 'package:zephyr_reader/features/learning_notes/page/widgets/note_list_widget.dart';
import 'package:zephyr_reader/features/learning_notes/page/widgets/stat_dashboard_widget.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/features/profile/page/widgets/settings_app_bar.dart';


/// 学习笔记页面。
///
/// 展示笔记/高亮列表，按书籍分组展示，不再使用横向筛选标签。
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

    return noteList.map(
      data: (List<NoteWithBook> noteList) => Scaffold(
        appBar: SettingsAppBar(title: l10n.selectionNote),
        body: Column(
          children: [
            LearningNotesStatDashboard(
              noteTotalCount: noteTotalCount.value ?? 0,
            ),
            Expanded(child: LearningNotesNoteList(groups: vm.groupedNotes)),
          ],
        ),
      ),
      error: () {},
      loading: () => Scaffold(
        appBar: SettingsAppBar(title: l10n.selectionNote),
        body: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
