library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:signals_hooks/signals_hooks.dart';

import 'package:path_provider/path_provider.dart';
import 'package:zephyr_reader/core/presentation/widgets/empty_state_widget.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/features/reader/application/note_manage_view_model.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class NoteManagePage extends HookWidget {
  final String bookId;
  final String bookTitle;

  const NoteManagePage({
    super.key,
    required this.bookId,
    required this.bookTitle,
  });

  @override
  Widget build(BuildContext context) {
    final vm = useMemoized(
      () => NoteManageViewModel(bookId: bookId, bookTitle: bookTitle),
    );
    final notes = useSignalValue<List<Note>, Signal<List<Note>>>(vm.notes);
    final loading = useSignalValue<bool, Signal<bool>>(vm.loading);

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('$bookTitle - 笔记'),
        actions: [
          if (!loading && notes.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(PhosphorIconsRegular.fileArrowDown),
              tooltip: '导出笔记',
              onSelected: (format) => doExport(context, format, notes, vm),
              itemBuilder: (c) => [
                const PopupMenuItem(
                  value: 'markdown',
                  child: Text('导出 Markdown'),
                ),
                const PopupMenuItem(value: 'txt', child: Text('导出纯文本')),
                const PopupMenuItem(value: 'html', child: Text('导出 HTML')),
              ],
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : notes.isEmpty
          ? EmptyStateWidget(
              icon: PhosphorIconsRegular.note,
              title: '暂无笔记',
              colorScheme: theme.colorScheme,
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: theme.dividerColor, width: 0.5),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        note.noteType == NoteType.highlight
                            ? PhosphorIconsRegular.highlighter
                            : PhosphorIconsRegular.notePencil,
                        size: 18,
                        color: note.noteType == NoteType.highlight
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              note.selectedText ?? note.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            SizedBox(height: DesignTokens.spacing(Spacing.xs)),
                            Text(
                              '第 ${note.chapterIndex + 1} 章',
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
                );
              },
            ),
    );
  }

  String _formatLabel(String format) {
    switch (format) {
      case 'markdown':
        return 'md';
      case 'html':
        return 'html';
      default:
        return 'txt';
    }
  }

  Future<void> doExport(
    BuildContext context,
    String format,
    List<Note> notes,
    NoteManageViewModel vm,
  ) async {
    try {
      final content = await vm.renderNotesToString(
        notes: notes,
        format: format,
      );
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final name = bookTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final ext = _formatLabel(format);
      final filename = '${name}_读书笔记_$ts.$ext';
      final file = File('${dir.path}/$filename');
      await file.writeAsString(content, flush: true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已导出: ${file.path}'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(label: '关闭', onPressed: () {}),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('导出失败: $e')));
      }
    }
  }
}
