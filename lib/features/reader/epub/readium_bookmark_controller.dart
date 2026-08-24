import 'dart:convert';

import 'package:signals_flutter/signals_flutter.dart';
import 'package:zephyr_reader/src/rust/api/bookmark.dart' as bookmark_api;
import 'package:zephyr_reader/src/rust/domain/bookmark/models.dart';
import 'package:flutter_readium/flutter_readium.dart';

typedef BookmarkErrorHandler = void Function(Object error);
typedef BookmarkCreator =
    Future<Bookmark> Function({
      required String bookId,
      required int chapterIndex,
      required int charOffset,
      required String title,
      String? locatorJson,
    });

class ReadiumBookmarkController {
  ReadiumBookmarkController({
    required this.bookId,
    required this.onError,
    required this.bookmarks,
    required this.isBookmarked,
    this.createBookmark = bookmark_api.createBookmark,
  });

  final String bookId;
  final BookmarkErrorHandler onError;
  final Signal<List<Bookmark>> bookmarks;
  final Signal<bool> isBookmarked;
  final BookmarkCreator createBookmark;
  bool _mutationInProgress = false;

  Future<void> load({Locator? currentLocator}) async {
    try {
      bookmarks.value = await bookmark_api.listBookmarksByBook(bookId: bookId);
      _updateState(locator: currentLocator);
    } catch (e) {
      onError(e);
    }
  }

  Future<void> add({
    required Locator locator,
    required int chapterIndex,
    required int charOffset,
    required String title,
  }) async {
    if (_mutationInProgress) return;
    final locatorJson = jsonEncode(locator.toJson());
    if (bookmarks.value.any((entry) => entry.locatorJson == locatorJson)) {
      return;
    }
    _mutationInProgress = true;
    try {
      final bookmark = await createBookmark(
        bookId: bookId,
        chapterIndex: chapterIndex,
        charOffset: charOffset,
        title: title,
        locatorJson: locatorJson,
      );
      bookmarks.value = [...bookmarks.value, bookmark];
      _updateState(locator: locator);
    } catch (e) {
      onError(e);
    } finally {
      _mutationInProgress = false;
    }
  }

  Future<void> removeCurrent(Locator locator) async {
    if (_mutationInProgress) return;
    final key = jsonEncode(locator.toJson());
    final match = bookmarks.value.where((b) => b.locatorJson == key);
    if (match.isEmpty) return;
    _mutationInProgress = true;
    try {
      await bookmark_api.deleteBookmark(bookmarkId: match.first.id);
      bookmarks.value = bookmarks.value
          .where((b) => b.id != match.first.id)
          .toList();
      _updateState(locator: locator);
    } catch (e) {
      onError(e);
    } finally {
      _mutationInProgress = false;
    }
  }

  Future<void> goTo(
    Bookmark entry, {
    required Future<void> Function(Locator locator) navigate,
  }) async {
    final locatorJson = entry.locatorJson;
    if (locatorJson == null) {
      final error = StateError('书签缺少定位信息');
      onError(error);
      throw error;
    }
    try {
      final locator = Locator.fromJson(
        jsonDecode(locatorJson) as Map<String, dynamic>,
      );
      if (locator == null) throw StateError('书签定位信息无效');
      await navigate(locator);
    } catch (e) {
      onError(e);
      rethrow;
    }
  }

  Future<void> delete(Bookmark entry) async {
    if (_mutationInProgress) return;
    _mutationInProgress = true;
    try {
      await bookmark_api.deleteBookmark(bookmarkId: entry.id);
      bookmarks.value = bookmarks.value.where((b) => b.id != entry.id).toList();
      _updateState();
    } catch (e) {
      onError(e);
    } finally {
      _mutationInProgress = false;
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
