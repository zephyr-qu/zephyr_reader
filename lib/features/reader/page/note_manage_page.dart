/// 笔记管理页面
library;

import 'package:flutter/material.dart';
import 'package:zephyr_reader/features/reader/data/note_service.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

/// 笔记管理页面
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
  final _noteService = NoteService.instance;
  List<DbNote> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  void _loadNotes() {
    setState(() => _loading = true);
    try {
      _notes = _noteService.getNotes(widget.bookId);
    } catch (_) {
      _notes = [];
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.bookTitle} - 笔记'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.note_alt_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('暂无笔记', style: TextStyle(fontSize: 16, color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    return ListTile(
                      leading: Icon(
                        note.noteType == DbNoteType.highlight
                            ? Icons.highlight
                            : Icons.notes,
                        color: note.noteType == DbNoteType.highlight
                            ? Colors.amber
                            : Colors.blue,
                      ),
                      title: Text(
                        note.selectedText ?? note.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '第 ${note.chapterIndex + 1} 章 · ${note.content.isNotEmpty ? note.content : ""}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
    );
  }
}
