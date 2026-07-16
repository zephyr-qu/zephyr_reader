import 'package:flutter_test/flutter_test.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/features/statistics/application/reading_sessions_view_model.dart';
import 'package:zephyr_reader/src/rust/domain/book/models.dart';
import 'package:zephyr_reader/src/rust/domain/sessions/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReadingSessionsViewModel — 初始状态', () {
    test('sessions 初始为 loading', () {
      final vm = ReadingSessionsViewModel();
      expect(vm.sessions.value, isA<AsyncLoading<List<ReadingSession>>>());
    });

    test('bookCache 初始为空映射', () {
      final vm = ReadingSessionsViewModel();
      expect(vm.bookCache.value, isEmpty);
    });
  });

  group('ReadingSessionsViewModel — 信号可更新', () {
    test('sessions 可设为 data', () {
      final vm = ReadingSessionsViewModel();
      final dummySession = ReadingSession(
        id: 'test-1',
        bookId: 'book-1',
        chapterIndex: 1,
        startCharOffset: 0,
        endCharOffset: 100,
        startedAt: DateTime(2024, 1, 1),
        endedAt: DateTime(2024, 1, 1, 0, 5),
        durationSeconds: 300,
      );
      vm.sessions.value = AsyncState.data([dummySession]);
      final state = vm.sessions.value;
      expect(state, isA<AsyncData<List<ReadingSession>>>());
      final data = (state as AsyncData<List<ReadingSession>>).value;
      expect(data.length, equals(1));
      expect(data.first.id, equals('test-1'));
    });

    test('sessions 可设为 error', () {
      final vm = ReadingSessionsViewModel();
      vm.sessions.value = AsyncState.error(Exception('test error'));
      final state = vm.sessions.value;
      expect(state, isA<AsyncError<List<ReadingSession>>>());
    });

    test('bookCache 信号可设值', () {
      final vm = ReadingSessionsViewModel();
      final dummyBook = Book(
        bookId: 'book-1',
        filePath: '/test/file.epub',
        fileSize: 1000,
        title: '测试书籍',
        chapterCount: 10,
        totalCharacters: 50000,
        format: BookFormat.epub,
        addedAt: DateTime(2024, 1, 1),
        status: BookStatus.reading,
        isPinned: false,
      );
      vm.bookCache.value = {'book-1': dummyBook};
      expect(vm.bookCache.value.length, equals(1));
      expect(vm.bookCache.value['book-1']?.title, equals('测试书籍'));
    });
  });
}
