import 'dart:convert';

import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/src/rust/api/bookmark.dart' as bookmark_api;
import 'package:zephyr_reader/src/rust/domain/bookmark/models.dart';
import 'package:flutter_readium/flutter_readium.dart';

typedef BookmarkErrorHandler = void Function(Object error);

class ReadiumBookmarkController {
  ReadiumBookmarkController({
    required this.bookId,
    required this.onError,
    required this.bookmarks,
    required this.isBookmarked,
  });

  final String bookId;
  final BookmarkErrorHandler onError;
  final Signal<List<Bookmark>> bookmarks;
  final Signal<bool> isBookmarked;

  Future<void> load() async {
    try {
      bookmarks.value = await bookmark_api.listBookmarksByBook(bookId: bookId);
      _updateState();
    } catch (_) {}
  }

  Future<void> add({
    required Locator locator,
    required int chapterIndex,
    required int charOffset,
    required String title,
  }) async {
    try {
      final bookmark = await bookmark_api.createBookmark(
        bookId: bookId,
        chapterIndex: chapterIndex,
        charOffset: charOffset,
        title: title,
        locatorJson: jsonEncode(locator.toJson()),
      );
      bookmarks.value = [...bookmarks.value, bookmark];
      _updateState();
    } catch (e) {
      onError(e);
    }
  }

  Future<void> removeCurrent(Locator locator) async {
    final key = jsonEncode(locator.toJson());
    final match = bookmarks.value.where((b) => b.locatorJson == key);
    if (match.isEmpty) return;
    try {
      await bookmark_api.deleteBookmark(bookmarkId: match.first.id);
      bookmarks.value = bookmarks.value
          .where((b) => b.locatorJson != key)
          .toList();
      _updateState();
    } catch (e) {
      onError(e);
    }
  }

  Future<void> goTo(
    Bookmark entry, {
    required Future<void> Function(Locator locator) navigate,
  }) async {
    final locatorJson = entry.locatorJson;
    if (locatorJson == null) return;
    try {
      final locator = Locator.fromJson(
        jsonDecode(locatorJson) as Map<String, dynamic>,
      );
      if (locator != null) await navigate(locator);
    } catch (e) {
      onError(e);
    }
  }

  Future<void> delete(Bookmark entry) async {
    try {
      await bookmark_api.deleteBookmark(bookmarkId: entry.id);
      bookmarks.value = bookmarks.value.where((b) => b.id != entry.id).toList();
      _updateState();
    } catch (e) {
      onError(e);
    }
  }

  void updateForLocator(Locator? locator) => _updateState(locator: locator);

  void _updateState({Locator? locator}) {
    final current = locator;
    if (current == null) {
      isBookmarked.value = false;
      return;
    }
    final key = jsonEncode(current.toJson());
    isBookmarked.value = bookmarks.value.any((b) => b.locatorJson == key);
  }
}
