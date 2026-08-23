import 'dart:convert';

import 'package:flutter_readium/flutter_readium.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/features/reader/epub/readium_bookmark_controller.dart';
import 'package:zephyr_reader/src/rust/domain/bookmark/models.dart';

void main() {
  test('marks the current locator after adding a bookmark', () async {
    final bookmarks = signal<List<Bookmark>>([]);
    final isBookmarked = signal(false);
    final locator = const Locator(
      href: 'chapter.xhtml',
      type: 'application/xhtml+xml',
      locations: Locations(position: 12, totalProgression: 0.4),
    );

    final controller = ReadiumBookmarkController(
      bookId: 'book-1',
      onError: (error) => fail('$error'),
      bookmarks: bookmarks,
      isBookmarked: isBookmarked,
      createBookmark:
          ({
            required bookId,
            required chapterIndex,
            required charOffset,
            required title,
            locatorJson,
          }) async {
            return Bookmark(
              id: 'bookmark-1',
              bookId: bookId,
              chapterIndex: chapterIndex,
              charOffset: charOffset,
              locatorJson: locatorJson,
              title: title,
              createdAt: DateTime(2026, 8, 23),
            );
          },
    );

    await controller.add(
      locator: locator,
      chapterIndex: 0,
      charOffset: 12,
      title: '第一章',
    );

    expect(bookmarks.value, hasLength(1));
    expect(bookmarks.value.single.locatorJson, jsonEncode(locator.toJson()));
    expect(isBookmarked.value, isTrue);
  });
}
