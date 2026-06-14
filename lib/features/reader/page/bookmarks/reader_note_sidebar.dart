import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/l10n/app_localizations.dart';
import 'package:zephyr_reader/features/reader/application/reader_view_model.dart';
import 'package:zephyr_reader/src/rust/api/data/note.dart' as note_api;
import 'package:zephyr_reader/src/rust/storage/models.dart';

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
    final notes = useState<List<Note>>([]);
    final loading = useState<bool>(true);

    Future<void> loadNotes() async {
      loading.value = true;
      try {
        notes.value = await note_api.listNotesByBook(bookId: bookId);
      } catch (_) {
        notes.value = [];
      }
      loading.value = false;
    }

    useEffect(() {
      loadNotes();
      return null;
    }, [bookId]);

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                20,
                DesignTokens.spacing(Spacing.md),
                DesignTokens.spacing(Spacing.sm),
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
                    onPressed: loadNotes,
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
              child: loading.value
                  ? const Center(child: CircularProgressIndicator())
                  : notes.value.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            PhosphorIconsRegular.note,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.3),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.noNotes,
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(
                        horizontal: DesignTokens.spacing(Spacing.md),
                      ),
                      itemCount: notes.value.length,
                      itemBuilder: (context, index) {
                        final note = notes.value[index];
                        return InkWell(
                          onTap: () {
                            Navigator.of(context).pop();
                            onNoteTap?.call(
                              note.chapterIndex,
                              note.charOffset.toInt(),
                            );
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
                                SizedBox(
                                  width: DesignTokens.spacing(Spacing.sm),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                      if (note.noteType ==
                                              NoteType.annotation &&
                                          note.content.isNotEmpty &&
                                          note.content !=
                                              (note.selectedText ?? ''))
                                        Padding(
                                          padding: EdgeInsets.only(
                                            top: DesignTokens.spacing(
                                              Spacing.xs,
                                            ),
                                          ),
                                          child: Text(
                                            note.content,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant
                                                  .withValues(alpha: 0.7),
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 2),
                                      Text(
                                        l10n.chapterN(note.chapterIndex + 1),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
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
            ),
          ],
        ),
      ),
    );
  }
}
