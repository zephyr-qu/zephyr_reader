import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/features/reader/core/application/reader_view_model.dart';
import 'package:zephyr_reader/src/rust/api/note.dart' as note_api;
import 'package:zephyr_reader/src/rust/domain/note/models.dart';


/// 阅读器笔记侧边栏。
///
/// 展示当前书籍的笔记/高亮列表，支持点击跳转到笔记位置。
class ReaderNoteSidebar extends HookWidget {
  final String bookId;
  final String bookTitle;
  final void Function(int chapterIndex, int charOffset)? onNoteTap;
  final ReaderViewModel vm;

  const ReaderNoteSidebar({
    super.key,
    required this.bookId,
    required this.bookTitle,
    required this.vm,
    this.onNoteTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    // useFutureSignal: 内置 lifecycle 绑定 + keys 变化时自动取消旧请求（race protection）。
    final notesAsync = useFutureSignal<List<Note>>(
      () => note_api.listNotesByBook(bookId: bookId),
      keys: [bookId],
    );

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                20,
                Spacing.md.value,
                Spacing.sm.value,
                12,
              ),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: theme.dividerColor)),
              ),
              child: Row(
                children: [
                  Text(
                    l10n.notesAndHighlights,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      PhosphorIconsRegular.arrowClockwise,
                      size: 20,
                    ),
                    onPressed: notesAsync.reload,
                    tooltip: l10n.refreshTooltip,
                  ),
                  IconButton(
                    icon: const Icon(PhosphorIconsLight.x, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: l10n.close,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _NotesBody(
                notesAsync: notesAsync,
                l10n: l10n,
                theme: theme,
                onNoteTap: onNoteTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 笔记列表主体：根据 notesAsync 状态渲染 loading / empty / list。
class _NotesBody extends StatelessWidget {
  const _NotesBody({
    required this.notesAsync,
    required this.l10n,
    required this.theme,
    required this.onNoteTap,
  });

  final FutureSignal<List<Note>> notesAsync;
  final AppLocalizations l10n;
  final ThemeData theme;
  final void Function(int chapterIndex, int charOffset)? onNoteTap;

  @override
  Widget build(BuildContext context) {
    return notesAsync.value.map<Widget>(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _NotesEmpty(theme: theme, l10n: l10n),
      data: (notes) => notes.isEmpty
          ? _NotesEmpty(theme: theme, l10n: l10n)
          : ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: Spacing.md.value),
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                return InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                    onNoteTap?.call(note.chapterIndex, note.charOffset.toInt());
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: theme.dividerColor,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          note.noteType == NoteType.highlight
                              ? PhosphorIconsRegular.highlighter
                              : PhosphorIconsRegular.note,
                          size: 16,
                          color: note.noteType == NoteType.highlight
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        SizedBox(width: Spacing.sm.value),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                note.selectedText ?? note.content,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              if (note.noteType == NoteType.annotation &&
                                  note.content.isNotEmpty &&
                                  note.content != (note.selectedText ?? ''))
                                Padding(
                                  padding: EdgeInsets.only(
                                    top: Spacing.xs.value,
                                  ),
                                  child: Text(
                                    note.content,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.chapterN(note.chapterIndex + 1),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// 笔记列表为空/错误占位。
class _NotesEmpty extends StatelessWidget {
  const _NotesEmpty({required this.theme, required this.l10n});

  final ThemeData theme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIconsRegular.note,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.noNotes,
            style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}
