library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/reader/data/note_repository.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class NoteManagePage extends StatefulWidget {
  final String bookId;
  final String bookTitle;

  const NoteManagePage({
    super.key,
    required this.bookId,
    required this.bookTitle,
  });

  @override
  State<NoteManagePage> createState() => _NoteManagePageState();
}

class _NoteManagePageState extends State<NoteManagePage> {
  final _noteService = getIt<NoteRepository>();
  List<Note> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    setState(() => _loading = true);
    try {
      _notes = await _noteService.getNotes(widget.bookId);
    } catch (_) {
      _notes = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  String _formatNotesAsMarkdown() {
    final buf = StringBuffer();
    buf.writeln('# ${widget.bookTitle} - 读书笔记');
    buf.writeln('---');
    buf.writeln();
    for (int i = 0; i < _notes.length; i++) {
      final n = _notes[i];
      buf.writeln(
        '## ${n.noteType == NoteType.highlight ? "高亮" : "笔记"} #${i + 1}',
      );
      buf.writeln();
      buf.writeln('- **章节**: 第 ${n.chapterIndex + 1} 章');
      if (n.selectedText != null && n.selectedText!.isNotEmpty) {
        buf.writeln('- **原文**: "${n.selectedText}"');
      }
      buf.writeln(
        '- **时间**: ${n.createdAt.toLocal().toString().substring(0, 19)}',
      );
      buf.writeln();
      if (n.content.isNotEmpty && n.content != (n.selectedText ?? '')) {
        buf.writeln('> ${n.content}');
        buf.writeln();
      }
      buf.writeln('---');
      buf.writeln();
    }
    buf.writeln();
    buf.writeln('*由 Zephyr Reader 导出*');
    return buf.toString();
  }

  Future<void> _exportMarkdown(BuildContext context) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final filename =
          '${widget.bookTitle}_读书笔记_${DateTime.now().millisecondsSinceEpoch}.md';
      final file = File('${dir.path}/$filename');
      await file.writeAsString(_formatNotesAsMarkdown());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已导出到: ${file.path}'),
            duration: const Duration(seconds: 4),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.bookTitle} - 笔记'),
        actions: [
          if (!_loading && _notes.isNotEmpty)
            IconButton(
              icon: const Icon(PhosphorIconsRegular.fileArrowDown),
              tooltip: '导出 Markdown',
              onPressed: () => _exportMarkdown(context),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    PhosphorIconsRegular.note,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.3,
                    ),
                  ),
                  SizedBox(height: DesignTokens.spacing(Spacing.md)),
                  Text(
                    '暂无笔记',
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _notes.length,
              itemBuilder: (context, index) {
                final note = _notes[index];
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
}
