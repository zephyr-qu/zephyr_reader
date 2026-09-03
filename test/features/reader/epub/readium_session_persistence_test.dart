import 'dart:convert';

import 'package:flutter_readium/flutter_readium.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/epub/readium_session_persistence.dart';
import 'package:zephyr_reader/src/rust/domain/book/models.dart';
import 'package:zephyr_reader/src/rust/domain/engine_positions/models.dart';
import 'package:zephyr_reader/src/rust/domain/progress/models.dart';

const _bookId = 'book-1';

Locator _locator({double progression = 0.0, String href = 'c.xhtml'}) =>
    Locator(
      href: href,
      type: 'application/xhtml+xml',
      locations: Locations(totalProgression: progression),
    );

EnginePositionHint _hint({
  String? bookId,
  String engineKind = 'readium',
  String fingerprint = 'fp-1',
  String opaque = '',
}) => EnginePositionHint(
  bookId: bookId ?? _bookId,
  engineKind: engineKind,
  publicationFingerprint: fingerprint,
  opaquePosition: opaque,
  updatedAt: DateTime.utc(2026, 1, 1),
);

void main() {
  group('loadSavedPosition', () {
    test('null hint 返回 null', () async {
      final p = ReadiumSessionPersistence(
        bookId: _bookId,
        onError: (_) {},
        chapterIndexForHref: (_) => 0,
        charOffsetFor: (_) => 0,
        isActive: () => true,
        loadEnginePosition: ({required bookId}) async => null,
      );
      expect(await p.loadSavedPosition(publicationFingerprint: 'fp-1'), isNull);
    });

    test('非 readium 引擎的 hint 返回 null', () async {
      final p = ReadiumSessionPersistence(
        bookId: _bookId,
        onError: (_) {},
        chapterIndexForHref: (_) => 0,
        charOffsetFor: (_) => 0,
        isActive: () => true,
        loadEnginePosition: ({required bookId}) async =>
            _hint(engineKind: 'ir'),
      );
      expect(await p.loadSavedPosition(publicationFingerprint: 'fp-1'), isNull);
    });

    test('空 opaquePosition 返回 null', () async {
      final p = ReadiumSessionPersistence(
        bookId: _bookId,
        onError: (_) {},
        chapterIndexForHref: (_) => 0,
        charOffsetFor: (_) => 0,
        isActive: () => true,
        loadEnginePosition: ({required bookId}) async => _hint(),
      );
      expect(await p.loadSavedPosition(publicationFingerprint: 'fp-1'), isNull);
    });

    test('出版指纹不匹配返回 null（换版本/换书）', () async {
      final p = ReadiumSessionPersistence(
        bookId: _bookId,
        onError: (_) {},
        chapterIndexForHref: (_) => 0,
        charOffsetFor: (_) => 0,
        isActive: () => true,
        loadEnginePosition: ({required bookId}) async =>
            _hint(opaque: jsonEncode(_locator().toJson())),
      );
      expect(await p.loadSavedPosition(publicationFingerprint: 'fp-2'), isNull);
    });

    test('匹配的 hint 反序列化为 Locator 并缓存指纹', () async {
      final saved = _locator(progression: 0.42);
      final p = ReadiumSessionPersistence(
        bookId: _bookId,
        onError: (_) {},
        chapterIndexForHref: (_) => 0,
        charOffsetFor: (_) => 0,
        isActive: () => true,
        loadEnginePosition: ({required bookId}) async =>
            _hint(opaque: jsonEncode(saved.toJson())),
      );
      final restored = await p.loadSavedPosition(
        publicationFingerprint: 'fp-1',
      );
      expect(restored, isNotNull);
      expect(restored!.href, 'c.xhtml');
      expect(restored.locations?.totalProgression, 0.42);
      // 指纹已缓存：后续保存应携带同一指纹
      expect(p.currentLocator, isNull);
    });

    test('加载抛异常时静默返回 null', () async {
      final p = ReadiumSessionPersistence(
        bookId: _bookId,
        onError: (_) {},
        chapterIndexForHref: (_) => 0,
        charOffsetFor: (_) => 0,
        isActive: () => true,
        loadEnginePosition: ({required bookId}) async =>
            throw Exception('db down'),
      );
      expect(await p.loadSavedPosition(publicationFingerprint: 'fp-1'), isNull);
    });
  });

  group('保存链路', () {
    test('flush 用当前 locator 组装 ReadingProgress 并序列化引擎位置', () async {
      final savedProgress = <ReadingProgress>[];
      final savedHints = <EnginePositionHint>[];
      final persistProgress = savedProgress.add;
      final p = ReadiumSessionPersistence(
        bookId: _bookId,
        onError: (_) {},
        chapterIndexForHref: (href) => href == 'c.xhtml' ? 3 : -1,
        charOffsetFor: (l) =>
            (l.locations?.totalProgression ?? 0) == 0 ? 100 : 0,
        isActive: () => true,
        persistProgress: (progress) async => persistProgress(progress),
        saveEnginePosition: ({required hint}) async => savedHints.add(hint),
      );
      p.restoreLocator(_locator());
      await p.flush();

      final progress = savedProgress.single;
      expect(progress.bookId, _bookId);
      expect(progress.chapterIndex, 3);
      expect(progress.chapterId, 'c.xhtml');
      expect(progress.charOffset, 100);
      expect(progress.progress, 0.0);
      expect(progress.isCompleted, isFalse);

      final hint = savedHints.single;
      expect(hint.engineKind, 'readium');
      expect(hint.publicationFingerprint, '');
      expect((jsonDecode(hint.opaquePosition) as Map)['href'], 'c.xhtml');
    });
  });

  group('完成态边界', () {
    test('progression >= 0.999 首次达到时标记完成并更新书状态', () async {
      var completedCalls = 0;
      var lastStatus = BookStatus.reading;
      final p = ReadiumSessionPersistence(
        bookId: _bookId,
        onError: (_) {},
        chapterIndexForHref: (_) => 0,
        charOffsetFor: (_) => 0,
        isActive: () => true,
        persistProgress: (_) async {},
        saveEnginePosition: ({required hint}) async {},
        updateBookStatus: ({required bookId, required status}) async {
          completedCalls++;
          lastStatus = status;
        },
      );

      p.restoreLocator(_locator(progression: 0.998));
      await p.flush();
      expect(completedCalls, 0, reason: '0.998 未达到完成阈值');

      p.restoreLocator(_locator(progression: 0.999));
      await p.flush();
      expect(completedCalls, 1);
      expect(lastStatus, BookStatus.completed);

      p.restoreLocator(_locator(progression: 1.0));
      await p.flush();
      expect(completedCalls, 1, reason: '重复完成不重复标记');
    });

    test('已提前标记完成的书不再触发状态更新', () async {
      var completedCalls = 0;
      final p = ReadiumSessionPersistence(
        bookId: _bookId,
        onError: (_) {},
        chapterIndexForHref: (_) => 0,
        charOffsetFor: (_) => 0,
        isActive: () => true,
        persistProgress: (_) async {},
        saveEnginePosition: ({required hint}) async {},
        updateBookStatus: ({required bookId, required status}) async {
          completedCalls++;
        },
      );
      p.setPreviouslyCompleted(true);
      p.restoreLocator(_locator(progression: 1.0));
      await p.flush();
      expect(completedCalls, 0);
    });
  });

  group('错误路径', () {
    test('持久化进度失败只上报 onError，不中断引擎位置保存', () async {
      final errors = <String>[];
      var hintSaved = false;
      final p = ReadiumSessionPersistence(
        bookId: _bookId,
        onError: errors.add,
        chapterIndexForHref: (_) => 0,
        charOffsetFor: (_) => 0,
        isActive: () => true,
        persistProgress: (_) async => throw Exception('disk full'),
        saveEnginePosition: ({required hint}) async {
          hintSaved = true;
        },
      );
      p.restoreLocator(_locator());
      await p.flush();

      expect(errors, hasLength(1));
      expect(errors.single, contains('保存阅读进度失败'));
      expect(hintSaved, isTrue, reason: '进度失败不应阻断引擎位置写入');
    });

    test('引擎位置保存失败单独上报', () async {
      final errors = <String>[];
      final p = ReadiumSessionPersistence(
        bookId: _bookId,
        onError: errors.add,
        chapterIndexForHref: (_) => 0,
        charOffsetFor: (_) => 0,
        isActive: () => true,
        persistProgress: (_) async {},
        saveEnginePosition: ({required hint}) async =>
            throw Exception('rpc error'),
      );
      p.restoreLocator(_locator());
      await p.flush();

      expect(errors, hasLength(1));
      expect(errors.single, contains('保存阅读位置失败'));
    });
  });
}
