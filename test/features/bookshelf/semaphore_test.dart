import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

class Semaphore {
  final int _max;
  int _count = 0;
  final _queue = <Completer<void>>[];

  Semaphore(this._max);

  Future<T> acquire<T>(Future<T> Function() fn) async {
    if (_count < _max) {
      _count++;
      try {
        return await fn();
      } finally {
        _release();
      }
    }
    final completer = Completer<void>();
    _queue.add(completer);
    await completer.future;
    return acquire(fn);
  }

  void _release() {
    if (_queue.isNotEmpty) {
      _queue.removeAt(0).complete();
    } else {
      _count--;
    }
  }
}

void main() {
  // Use runZoned to avoid flutter_test fake async timeouts
  test('handles single task', () async {
    final sem = Semaphore(4);
    final result = await sem.acquire(() async => 42);
    expect(result, 42);
  });

  test('handles error propagation', () async {
    final sem = Semaphore(2);
    expect(
      () => sem.acquire<int>(() async => throw Exception('boom')),
      throwsA(isA<Exception>()),
    );
  });

  test('releases after error', () async {
    final sem = Semaphore(1);
    await expectLater(
      sem.acquire(() async => throw Exception('fail')),
      throwsA(isA<Exception>()),
    );
    final result = await sem.acquire(() async => 'ok');
    expect(result, 'ok');
  });
}
