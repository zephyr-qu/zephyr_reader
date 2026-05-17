library;

import 'package:flutter/material.dart';
import 'package:zephyr_reader/core/theme/theme_constants.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/reader/data/note_repository.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

class ReaderNoteSidebar extends StatefulWidget {
  final String bookId;
  final String bookTitle;
  final void Function(int chapterIndex, int charOffset)? onNoteTap;

  const ReaderNoteSidebar({super.key, required this.bookId, required this.bookTitle, this.onNoteTap});

  @override
  State<ReaderNoteSidebar> createState() => _ReaderNoteSidebarState();
}

class _ReaderNoteSidebarState extends State<ReaderNoteSidebar> {
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
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: DesignTokens.divider)),
              ),
              child: Row(
                children: [
                  const Text('笔记与标注',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: DesignTokens.textPrimary),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: _loadNotes,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _notes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.note_alt_outlined, size: 48,
                            color: DesignTokens.textSecondary.withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          const Text('暂无笔记', style: TextStyle(fontSize: 14, color: DesignTokens.textPrimary)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _notes.length,
                      itemBuilder: (context, index) {
                        final note = _notes[index];
                        return InkWell(
                          onTap: () {
                            Navigator.of(context).pop();
                            widget.onNoteTap?.call(note.chapterIndex, note.charOffset.toInt());
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: DesignTokens.divider, width: 0.5)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  note.noteType == NoteType.highlight ? Icons.highlight : Icons.notes,
                                  size: 16, color: note.noteType == NoteType.highlight
                                    ? DesignTokens.primary : DesignTokens.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(note.selectedText ?? note.content,
                                        maxLines: 2, overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13, color: DesignTokens.textPrimary),
                                      ),
                                      if (note.noteType == NoteType.annotation && note.content.isNotEmpty
                                        && note.content != (note.selectedText ?? ''))
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(note.content,
                                            maxLines: 2, overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 12, color: DesignTokens.textSecondary.withValues(alpha: 0.7))),
                                        ),
                                      const SizedBox(height: 2),
                                      Text('第 ${note.chapterIndex + 1} 章',
                                        style: const TextStyle(fontSize: 11, color: DesignTokens.textSecondary),
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
