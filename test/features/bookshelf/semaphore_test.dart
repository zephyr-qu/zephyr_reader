// test/features/bookshelf/semaphore_test.dart
//
// Semaphore 单元测试 — acquire/release 正反场景覆盖。
// 验证 while(true) 循环实现（非递归）的并发控制正确性。

import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/bookshelf/application/book_import_service.dart';

void main() {
  group('Semaphore positive scenarios', () {
    test('single task acquires and returns result', () async {
      final sem = Semaphore(4);
      final result = await sem.acquire(() async => 42);
      expect(result, 42);
    });

    test('acquires up to max concurrent tasks', () async {
      final sem = Semaphore(2);
      var running = 0;
      var maxConcurrent = 0;

      Future<void> task(int id) => sem.acquire(() async {
        running++;
        if (running > maxConcurrent) maxConcurrent = running;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        running--;
      });

      await Future.wait([task(1), task(2), task(3), task(4)]);
      expect(maxConcurrent, lessThanOrEqualTo(2));
    });

    test('tasks execute in FIFO order', () async {
      final sem = Semaphore(1);
      final order = <int>[];

      Future<void> task(int id) => sem.acquire(() async {
        order.add(id);
        await Future<void>.delayed(const Duration(milliseconds: 5));
      });

      await Future.wait([task(1), task(2), task(3)]);
      expect(order, [1, 2, 3]);
    });

    test('releases slot after task completes, allowing next to run', () async {
      final sem = Semaphore(1);
      final completed = <String>[];
      await Future.wait([
        sem.acquire(() async {
          completed.add('first');
        }),
        sem.acquire(() async {
          completed.add('second');
        }),
      ]);
      expect(completed, ['first', 'second']);
    });

    test('max=1 creates strict sequential execution', () async {
      final sem = Semaphore(1);
      var running = 0;
      var sawOverlap = false;

      Future<void> task() => sem.acquire(() async {
        if (running > 0) sawOverlap = true;
        running++;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        running--;
      });

      await Future.wait([task(), task(), task()]);
      expect(sawOverlap, isFalse);
    });
  });

  group('Semaphore negative scenarios', () {
    test('propagates task error to caller', () async {
      final sem = Semaphore(2);
      expect(
        () => sem.acquire<int>(() async => throw Exception('task failed')),
        throwsA(isA<Exception>()),
      );
    });

    test('releases slot after task throws, allowing next task', () async {
      final sem = Semaphore(1);

      await expectLater(
        sem.acquire(() async => throw Exception('fail')),
        throwsA(isA<Exception>()),
      );

      // Next task should succeed — slot was released
      final result = await sem.acquire(() async => 'recovered');
      expect(result, 'recovered');
    });

    test(
      'multiple tasks with mixed success/failure preserve slot count',
      () async {
        final sem = Semaphore(2);
        var running = 0;
        var maxRunning = 0;

        Future<void> task({required bool shouldThrow}) => sem.acquire(() async {
          running++;
          if (running > maxRunning) maxRunning = running;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          try {
            if (shouldThrow) throw Exception('fail');
          } finally {
            running--;
          }
        });

        await Future.wait([
          task(shouldThrow: false),
          task(shouldThrow: true).catchError((_) {}),
          task(shouldThrow: false),
          task(shouldThrow: true).catchError((_) {}),
          task(shouldThrow: false),
        ]);
        expect(maxRunning, lessThanOrEqualTo(2));
        expect(running, 0); // all released
      },
    );
  });

  group('Semaphore concurrent edge cases', () {
    test(
      'zero max allows no tasks (stuck, but release on error works)',
      () async {
        final sem = Semaphore(0);

        // With max=0, tasks get queued forever unless timeout is used.
        // Test that Semaphore(0) doesn't crash — it just blocks.
        var completed = false;
        final task = sem
            .acquire(() async {
              completed = true;
            })
            .timeout(
              const Duration(milliseconds: 50),
              onTimeout: () {
                // Expected: never completes because count can never be < 0
              },
            );
        await task;
        expect(completed, isFalse);
      },
    );

    test('large max allows many concurrent tasks', () async {
      final sem = Semaphore(100);
      final count = 50;
      var running = 0;
      var maxRunning = 0;

      Future<void> task() => sem.acquire(() async {
        running++;
        if (running > maxRunning) maxRunning = running;
        await Future<void>.delayed(const Duration(milliseconds: 1));
        running--;
      });

      await Future.wait(List.generate(count, (_) => task()));
      expect(maxRunning, count);
    });
  });
}
