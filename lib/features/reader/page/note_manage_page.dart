library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:path_provider/path_provider.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/src/rust/api/data/note.dart' as note_api;
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
      _notes = await note_api.listNotesByBook(bookId: widget.bookId);
    } catch (_) {
      _notes = [];
    }
    if (mounted) setState(() => _loading = false);
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

  Future<void> _doExport(String format) async {
    try {
      final content = await note_api.renderNotesToString(
        notes: _notes,
        bookTitle: widget.bookTitle,
        format: format,
      );
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final name = widget.bookTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final ext = _formatLabel(format);
      final filename = '${name}_读书笔记_$ts.$ext';
      final file = File('${dir.path}/$filename');
      await file.writeAsString(content, flush: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已导出: ${file.path}'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(label: '关闭', onPressed: () {}),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
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
            PopupMenuButton<String>(
              icon: const Icon(PhosphorIconsRegular.fileArrowDown),
              tooltip: '导出笔记',
              onSelected: (format) => _doExport(format),
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
