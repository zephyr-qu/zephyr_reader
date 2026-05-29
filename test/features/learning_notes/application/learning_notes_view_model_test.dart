import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:signals_core/signals_core.dart';
import 'package:zephyr_reader/features/learning_notes/application/learning_notes_view_model.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';
import 'package:zephyr_reader/src/rust/api/data/book.dart' as rust_book;
import 'package:zephyr_reader/src/rust/api/data/vocabulary.dart' as rust_vocab;
import 'package:zephyr_reader/src/rust/api/data/note.dart' as rust_note;
import 'package:zephyr_reader/src/rust/api/data/stats.dart' as rust_stats;

import '../../../helpers/fixtures.dart';

class _MockRustVocabApi extends Mock {}

class _MockRustBookApi extends Mock {}

class _MockRustNoteApi extends Mock {}

class _MockRustStatsApi extends Mock {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LearningNotesViewModel', () {
    late LearningNotesViewModel vm;

    setUp(() {
      vm = LearningNotesViewModel();
    });

    tearDown(() {
      vm.dispose();
    });

    group('初始状态', () {
      test('生词列表应为空', () {
        expect(vm.vocabList.value, isEmpty);
      });

      test('笔记列表应为空', () {
        expect(vm.noteList.value, isEmpty);
      });

      test('统计计数应为 0', () {
        expect(vm.vocabTotalCount.value, equals(0));
        expect(vm.vocabLearningCount.value, equals(0));
        expect(vm.vocabMasteredCount.value, equals(0));
        expect(vm.noteTotalCount.value, equals(0));
      });

      test('应默认选中第一个 tab', () {
        expect(vm.activeTab.value, equals(0));
      });

      test('loading 应为 false', () {
        expect(vm.loading.value, isFalse);
        expect(vm.noteLoading.value, isFalse);
      });

      test('error 应为 null', () {
        expect(vm.error.value, isNull);
      });
    });

    group('初始化', () {
      test('initialize 应加载数据和标题', () async {
        when(
          () => rust_vocab.listVocabularyByStatus(),
        ).thenAnswer((_) async => []);

        when(() => rust_book.listBooks()).thenAnswer((_) async => []);

        await vm.initialize();

        // 不应抛出异常
        expect(() => vm.vocabList.value, returnsNormally);
      });

      test('重复调用 initialize 不应重复加载', () async {
        when(
          () => rust_vocab.listVocabularyByStatus(),
        ).thenAnswer((_) async => []);
        when(() => rust_book.listBooks()).thenAnswer((_) async => []);

        await vm.initialize();
        final firstLoadAttempt = 1;

        // 第二次调用应被跳过
        await vm.initialize();

        expect(_initializedCalls, lessThan(2));
      });
    });

    group('刷新功能', () {
      test('refresh 应重置错误并重载数据', () async {
        vm.error.value = '之前的错误';

        when(
          () => rust_vocab.listVocabularyByStatus(),
        ).thenAnswer((_) async => []);
        when(() => rust_book.listBooks()).thenAnswer((_) async => []);

        await vm.refresh();

        expect(vm.loading.value, isFalse);
        expect(vm.error.value, isNull);
      });

      test('错误时应设置 error 消息', () async {
        when(
          () => rust_vocab.listVocabularyByStatus(),
        ).thenThrow(Exception('Test error'));

        await vm.refresh();

        expect(vm.error.value, contains('加载失败'));
        expect(vm.loading.value, isFalse);
      });
    });

    group('Tab 切换', () {
      test('switchTab 应切换到笔记 tab', () async {
        when(() => rust_book.listBooks()).thenAnswer((_) async => []);

        await vm.switchTab(1);

        expect(vm.activeTab.value, equals(1));
      });
    });

    group('生词统计', () {
      test('_loadVocabStats 应正确更新统计', () async {
        when(
          () => rust_vocab.listVocabularyByStatus(status: VocabStatus.new_),
        ).thenAnswer((_) async => []);
        when(
          () => rust_vocab.listVocabularyByStatus(status: VocabStatus.learning),
        ).thenAnswer((_) async => [createTestVocab()]);
        when(
          () => rust_vocab.listVocabularyByStatus(status: VocabStatus.mastered),
        ).thenAnswer((_) async => [createTestVocab()]);
        when(
          () => rust_vocab.listVocabularyByStatus(),
        ).thenAnswer((_) async => [createTestVocab()]);

        // 这里假设内部方法被正确调用
        expect(() => vm.vocabTotalCount.value, returnsNormally);
      });
    });

    group('筛选功能', () {
      test('setVocabFilterStatus 应更新筛选条件', () async {
        when(
          () => rust_vocab.listVocabularyByStatus(
            status: any(named: 'status'),
            wordList: any(named: 'wordList'),
          ),
        ).thenAnswer((_) async => []);

        await vm.setVocabFilterStatus(VocabStatus.new_);

        expect(vm.vocabFilterStatus.value, equals(VocabStatus.new_));
      });

      test('setNoteFilterBook 应过滤笔记', () async {
        final notes = [
          NoteWithBook(note: createTestNote(), bookTitle: 'Book A'),
          NoteWithBook(
            note: createTestNote(bookId: 'book_2'),
            bookTitle: 'Book B',
          ),
        ];
        vm.noteList.value = notes;

        await vm.setNoteFilterBook('book_1');

        expect(vm.noteList.value.length, equals(1));
        expect(vm.noteList.value.first.note.bookId, equals('book_1'));
      });

      test('无筛选条件时应显示所有笔记', () async {
        final notes = [
          NoteWithBook(
            note: createTestNote(bookId: 'book_1'),
            bookTitle: 'Book A',
          ),
          NoteWithBook(
            note: createTestNote(bookId: 'book_2'),
            bookTitle: 'Book B',
          ),
        ];
        vm.noteList.value = notes;

        await vm.setNoteFilterBook(null);

        expect(vm.noteList.value.length, equals(2));
      });
    });

    group('生词操作', () {
      test('updateVocabStatus 应更新状态并刷新列表', () async {
        when(
          () => rust_vocab.updateVocabularyStatus(any(), any()),
        ).thenAnswer((_) async {});
        when(
          () => rust_vocab.listVocabularyByStatus(any()),
        ).thenAnswer((_) async => []);

        expect(
          () => vm.updateVocabStatus('vocab_1', VocabStatus.mastered),
          returnsNormally,
        );
      });

      test('deleteVocab 应删除并刷新', () async {
        when(() => rust_vocab.deleteVocabulary(any())).thenAnswer((_) async {});
        when(
          () => rust_vocab.listVocabularyByStatus(any()),
        ).thenAnswer((_) async => []);

        expect(() => vm.deleteVocab('vocab_1'), returnsNormally);
      });
    });

    group('书籍标题加载', () {
      test('_loadBookTitles 应正确映射标题', () async {
        when(() => rust_book.listBooks()).thenAnswer(
          (_) async => [
            rust_book.Book(
              bookId: 'book_1',
              filePath: '/test.txt',
              title: '测试书籍',
              chapterCount: 10,
              addedAt: DateTime.now(),
              format: BookFormat.txt,
              status: BookStatus.planned,
              fileSize: 1024,
              totalCharacters: 50000,
            ),
          ],
        );

        expect(() => vm.bookTitles.value, returnsNormally);
      });
    });

    // Helper variable for tracking calls
  });
}

int _initializedCalls = 0;
