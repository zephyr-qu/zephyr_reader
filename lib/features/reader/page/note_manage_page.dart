library;

import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/reader/data/note_repository.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class NoteManagePage extends StatefulWidget {
  final String bookId;
  final String bookTitle;

  const NoteManagePage({super.key, required this.bookId, required this.bookTitle});

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.bookTitle} - 笔记')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.note_alt_outlined, size: 64, color: DesignTokens.textSecondary.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      const Text('暂无笔记', style: TextStyle(fontSize: 16, color: DesignTokens.textPrimary)),
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
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: DesignTokens.divider, width: 0.5)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            note.noteType == NoteType.highlight ? Icons.highlight : Icons.notes,
                            size: 18,
                            color: note.noteType == NoteType.highlight
                              ? DesignTokens.primary : DesignTokens.textSecondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(note.selectedText ?? note.content,
                                  maxLines: 2, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14, color: DesignTokens.textPrimary),
                                ),
                                const SizedBox(height: 4),
                                Text('第 ${note.chapterIndex + 1} 章',
                                  style: const TextStyle(fontSize: 12, color: DesignTokens.textSecondary),
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
