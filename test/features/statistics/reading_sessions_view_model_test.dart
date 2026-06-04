import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/statistics/application/reading_sessions_view_model.dart';
import 'package:zephyr_reader/src/rust/storage/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReadingSessionsViewModel — 初始状态', () {
    test('sessions 初始为空列表', () {
      final vm = ReadingSessionsViewModel();
      expect(vm.sessions.value, isEmpty);
    });

    test('bookCache 初始为空映射', () {
      final vm = ReadingSessionsViewModel();
      expect(vm.bookCache.value, isEmpty);
    });

    test('loaded 初始为 false', () {
      final vm = ReadingSessionsViewModel();
      expect(vm.loaded.value, isFalse);
    });

    test('loading 初始为 false', () {
      final vm = ReadingSessionsViewModel();
      expect(vm.loading.value, isFalse);
    });
  });

  group('ReadingSessionsViewModel — 信号可更新', () {
    test('sessions 信号可设值', () {
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
      vm.sessions.value = [dummySession];
      expect(vm.sessions.value.length, equals(1));
      expect(vm.sessions.value.first.id, equals('test-1'));
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

    test('loaded 信号可切换为 true', () {
      final vm = ReadingSessionsViewModel();
      vm.loaded.value = true;
      expect(vm.loaded.value, isTrue);
    });

    test('loading 信号可切换为 true', () {
      final vm = ReadingSessionsViewModel();
      vm.loading.value = true;
      expect(vm.loading.value, isTrue);
    });
  });
}
