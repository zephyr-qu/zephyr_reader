import 'package:flutter_readium/flutter_readium.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_reader/features/reader/epub/readium_session_tracker.dart';

void main() {
  test(
    'active seconds accumulate from short page-turn gaps and cap idle gaps',
    () async {
      final recorded = <({int durationSeconds})>[];
      final tracker = ReadiumSessionTracker(
        bookId: 'book',
        recordSession:
            ({
              required bookId,
              required chapterIndex,
              required startedAt,
              required durationSeconds,
            }) async {
              recorded.add((durationSeconds: durationSeconds));
            },
        chapterIndexForHref: (_) => 0,
        charOffsetFor: (Locator l) => l.locations?.totalProgression != null
            ? (l.locations!.totalProgression! * 1000).round()
            : 0,
        isActive: () => true,
      );

      // 首翻页建立会话
      tracker.track(
        const Locator(
          href: 'c.xhtml',
          type: 'application/xhtml+xml',
          locations: Locations(totalProgression: 0.0),
        ),
      );
      // 快速连续翻页（间隔很小）
      tracker.track(
        const Locator(
          href: 'c.xhtml',
          type: 'application/xhtml+xml',
          locations: Locations(totalProgression: 0.05),
        ),
      );
      // 长间隔后 finalize：该段不应计入
      await Future<void>.delayed(const Duration(milliseconds: 50));
      tracker.track(
        const Locator(
          href: 'c.xhtml',
          type: 'application/xhtml+xml',
          locations: Locations(totalProgression: 0.10),
        ),
      );
      await tracker.finalize();

      expect(recorded, hasLength(1));
      final duration = recorded.single.durationSeconds;
      // 两次短间隔（<1s 计 0s，但首末窗口补偿）应远小于 wall-clock
      expect(duration, lessThan(5));
      expect(duration, greaterThanOrEqualTo(0));
    },
  );

  test('finalize with no progress records zero duration', () async {
    final recorded = <({int durationSeconds})>[];
    final tracker = ReadiumSessionTracker(
      bookId: 'book',
      recordSession:
          ({
            required bookId,
            required chapterIndex,
            required startedAt,
            required durationSeconds,
          }) async {
            recorded.add((durationSeconds: durationSeconds));
          },
      chapterIndexForHref: (_) => 0,
      charOffsetFor: (Locator l) => l.locations?.totalProgression != null
          ? (l.locations!.totalProgression! * 1000).round()
          : 0,
      isActive: () => true,
    );

    tracker.track(
      const Locator(
        href: 'c.xhtml',
        type: 'application/xhtml+xml',
        locations: Locations(totalProgression: 0.0),
      ),
    );
    await tracker.finalize();

    expect(recorded, hasLength(1));
    expect(recorded.single.durationSeconds, 0);
  });
}
