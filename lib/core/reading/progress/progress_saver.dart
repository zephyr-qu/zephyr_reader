import 'dart:async';

import 'package:flureadium/flureadium.dart';
import 'package:zephyr_reader/src/rust/api/progress.dart' as progress_api;
import 'package:zephyr_reader/src/rust/domain/progress/models.dart';

/// Saves reading progress to the Rust persistence layer.
///
/// Handles throttling, chapter index extraction via a callback,
/// and force-flush on exit/background.
class ProgressSaver {
  Timer? _throttleTimer;
  Locator? _pendingLocator;
  String _bookId = '';
  int? Function(String href)? _hrefToChapterIndex;

  static const _throttleDuration = Duration(seconds: 3);

  /// Set the book ID for subsequent saves.
  void setBookId(String bookId) {
    _bookId = bookId;
  }

  /// Provide a resolver for href → chapter index.
  ///
  /// Typically wired to [ReadiumChapterMapper.indexForHref].
  void setHrefResolver(int? Function(String href) resolver) {
    _hrefToChapterIndex = resolver;
  }

  /// Called on every locator change from the viewport.
  ///
  /// Saves are throttled to avoid writing on every frame.
  void onLocatorChanged(Locator locator) {
    _pendingLocator = locator;
    _throttleTimer?.cancel();
    _throttleTimer = Timer(_throttleDuration, () {
      _doSave();
    });
  }

  /// Force-flush the pending position immediately.
  ///
  /// Call on reader close, app background, or explicit save.
  Future<void> flush() async {
    _throttleTimer?.cancel();
    if (_pendingLocator != null) {
      await _doSave();
    }
  }

  /// Release resources.
  void dispose() {
    _throttleTimer?.cancel();
    _throttleTimer = null;
    _pendingLocator = null;
  }

  Future<void> _doSave() async {
    final locator = _pendingLocator;
    if (locator == null || _bookId.isEmpty) return;

    try {
      final totalProgression = locator.locations?.totalProgression ?? 0.0;
      final chapterIndex = _hrefToChapterIndex?.call(locator.href) ?? 0;

      final progress = ReadingProgress.newInstance(
        bookId: _bookId,
        chapterIndex: chapterIndex,
        chunkIndex: 0, // Not used in Readium mode
        charOffset: 0, // Char-level offset is Locator→ReadingPosition mapping
        progress: totalProgression,
        readingTimeSeconds: 0, // Timer managed by ReaderFeatureCoordinator
        isCompleted: totalProgression >= 1.0,
      );

      await progress_api.upsertProgress(progress: await progress);
    } catch (_) {
      // Silently ignore save failures to avoid crashing the reader.
    }
  }
}
