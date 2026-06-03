

import 'dart:async';

import 'package:injectable/injectable.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/shared/book_title_resolver.dart';
import 'package:zephyr_reader/src/rust/api/data/book.dart' as rust_book;
import 'package:zephyr_reader/src/rust/api/data/note.dart' as rust_note;
import 'package:zephyr_reader/src/rust/api/data/stats.dart' as rust_stats;
import 'package:zephyr_reader/src/rust/api/data/vocabulary.dart' as rust_vocab;
import 'package:zephyr_reader/src/rust/storage/models.dart';

@injectable
class LearningNotesViewModel {
  final vocabList = signal<List<Vocab>>([]);
  final noteList = signal<List<NoteWithBook>>([]);
  final vocabTotalCount = signal<int>(0);
  final vocabLearningCount = signal<int>(0);
  final vocabMasteredCount = signal<int>(0);
  final noteTotalCount = signal<int>(0);
  final loading = signal<bool>(false);
  final noteLoading = signal<bool>(false);
  final error = signal<String?>(null);

  final activeTab = signal<int>(0);
  final vocabFilterStatus = signal<VocabStatus?>(null);
  final vocabFilterWordList = signal<String?>(null);
  final noteFilterBookId = signal<String?>(null);

  final bookTitles = signal<Map<String, String>>({});

  bool _initialized = false;
  bool _noteLoadAttempted = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await Future.wait([_loadVocabStats(), _loadVocabList(), _loadBookTitles()]);
    unawaited(_loadNoteCount());
  }

  Future<void> refresh() async {
    loading.value = true;
    error.value = null;
    _noteLoadAttempted = false;
    try {
      await Future.wait([
        _loadVocabStats(),
        _loadVocabList(),
        _loadBookTitles(),
      ]);
      if (activeTab.value == 1) {
        await _loadNotes();
      } else {
        unawaited(_loadNoteCount());
      }
    } catch (e) {
      error.value = '加载失败: $e';
    } finally {
      loading.value = false;
    }
  }

  Future<void> switchTab(int index) async {
    activeTab.value = index;
    if (index == 1) {
      await _loadNotes();
    }
  }

  Future<void> setVocabFilterStatus(VocabStatus? status) async {
    vocabFilterStatus.value = status;
    await _loadVocabList();
  }

  Future<void> setVocabFilterWordList(String? wordList) async {
    vocabFilterWordList.value = wordList;
    await _loadVocabList();
  }

  Future<void> setNoteFilterBook(String? bookId) async {
    noteFilterBookId.value = bookId;
    noteList.value = _allNotes.where((n) {
      if (bookId == null) return true;
      return n.note.bookId == bookId;
    }).toList();
  }

  Future<void> updateVocabStatus(String id, VocabStatus status) async {
    await rust_vocab.updateVocabularyStatus(id: id, status: status);
    await Future.wait([_loadVocabStats(), _loadVocabList()]);
  }

  Future<void> deleteVocab(String id) async {
    await rust_vocab.deleteVocabulary(id: id);
    await Future.wait([_loadVocabStats(), _loadVocabList()]);
  }

  List<NoteWithBook> _allNotes = [];

  Future<void> _loadVocabStats() async {
    try {
      final results = await Future.wait([
        rust_vocab.listVocabularyByStatus(status: VocabStatus.new_),
        rust_vocab.listVocabularyByStatus(status: VocabStatus.learning),
        rust_vocab.listVocabularyByStatus(status: VocabStatus.mastered),
        rust_vocab.listVocabularyByStatus(),
      ]);
      vocabLearningCount.value = results[1].length;
      vocabMasteredCount.value = results[2].length;
      final all = results[3];
      vocabTotalCount.value = all.length;
    } catch (e) {
      Logging.error('加载学习统计数据失败', exception: e);
    }
  }

  Future<void> _loadVocabList() async {
    try {
      final list = await rust_vocab.listVocabularyByStatus(
        status: vocabFilterStatus.value,
        wordList: vocabFilterWordList.value,
      );
      vocabList.value = list;
    } catch (e) {
      error.value = '加载生词失败: $e';
    }
  }

  Future<void> _loadNoteCount() async {
    try {
      final global = await rust_stats.getGlobalReadingStats();
      noteTotalCount.value = global.totalNotesCount;
    } catch (e) {
      Logging.error('加载笔记总数失败', exception: e);
    }
  }

  Future<void> _loadNotes() async {
    if (_noteLoadAttempted) return;
    _noteLoadAttempted = true;
    noteLoading.value = true;
    try {
      final books = await rust_book.listBooks();
      final bookMap = <String, String>{};
      final allNotes = <NoteWithBook>[];
      for (final book in books) {
        bookMap[book.bookId] = book.title;
        final notes = await rust_note.listNotesByBook(bookId: book.bookId);
        for (final note in notes) {
          allNotes.add(NoteWithBook(note: note, bookTitle: book.title));
        }
      }
      allNotes.sort((a, b) => b.note.createdAt.compareTo(a.note.createdAt));
      bookTitles.value = bookMap;
      _allNotes = allNotes;
      noteList.value = allNotes;
      noteTotalCount.value = allNotes.length;
    } catch (e) {
      error.value = '加载笔记失败: $e';
    } finally {
      noteLoading.value = false;
    }
  }

  Future<void> _loadBookTitles() async {
    bookTitles.value = await loadBookTitles();
  }
}

class NoteWithBook {
  final Note note;
  final String bookTitle;
  const NoteWithBook({required this.note, required this.bookTitle});
}
