import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flureadium/flureadium.dart';
import 'package:zephyr_reader/src/rust/api/note.dart' as note_api;
import 'package:zephyr_reader/src/rust/domain/note/models.dart';

import '../reading_backend.dart';
import '../reading_backend_kind.dart';
import '../reading_capabilities.dart';
import '../reading_command.dart';
import '../reading_open_request.dart';
import '../reading_snapshot.dart';
import '../reading_status.dart';
import '../../preferences/reading_preferences.dart';
import '../../chapter/reading_chapter.dart';
import '../../progress/progress_saver.dart';
import 'readium_chapter_mapper.dart';
import 'readium_preferences_mapper.dart';
import 'readium_decoration_mapper.dart';
import 'readium_session.dart';

/// Readium reading backend wrapping [ReadiumSession].
///
/// Maps the engine-neutral [ReadingBackend] seam to the flureadium API.
class ReadiumReadingBackend implements ReadingBackend {
  @override
  final ReadingBackendKind kind = ReadingBackendKind.readium;

  @override
  final ReadingCapabilities capabilities = ReadingCapabilities.readium;

  @override
  final ValueNotifier<ReadingSnapshot> snapshot;

  final ReadiumSession _session;

  Locator? _lastLocator;
  String _bookId = '';
  ReadiumChapterMapper? _chapterMapper;
  final ProgressSaver _progressSaver = ProgressSaver();
  final ReadiumPreferencesMapper _prefsMapper =
      const ReadiumPreferencesMapper();
  final ReadiumDecorationMapper _decorationMapper =
      const ReadiumDecorationMapper();
  Timer? _prefsDebounce;

  /// Latest known locator from the viewport.
  Locator? get currentLocator => _lastLocator;

  /// Called after chapters are parsed from the publication.
  void Function(List<ReadingChapter> chapters)? onChaptersReady;

  ReadiumReadingBackend({ReadiumSession? session})
    : _session = session ?? ReadiumSession(),
      snapshot = ValueNotifier<ReadingSnapshot>(ReadingSnapshot.closed) {
    _setupCallbacks();
  }

  // ---------------------------------------------------------------
  // Callback wiring
  // ---------------------------------------------------------------

  void _setupCallbacks() {
    _session.onStateChanged = (state) {
      switch (state) {
        case ReadiumSessionState.idle:
          _emitSnapshot(ReadingStatus.closed);
        case ReadiumSessionState.opening:
          _emitSnapshot(ReadingStatus.opening);
        case ReadiumSessionState.ready:
          _buildChapterMapper();
          _applyDecorations();
          _emitSnapshot(ReadingStatus.ready);
        case ReadiumSessionState.failed:
          _emitSnapshot(ReadingStatus.failed, errorMessage: 'Session failed');
      }
    };

    _session.onLocatorChanged = (locator) {
      _lastLocator = locator;
      final title = locator.title ?? '';
      _emitSnapshot(ReadingStatus.ready,
          chapterTitle: title,
          totalProgress: locator.locations?.totalProgression ?? 0.0);
      _progressSaver.onLocatorChanged(locator);
    };

    _session.onError = (message) {
      _emitSnapshot(ReadingStatus.failed, errorMessage: message);
    };
  }

  void _buildChapterMapper() {
    final pub = _session.publication;
    if (pub == null) return;
    _chapterMapper = ReadiumChapterMapper(pub);
    final chapters = _chapterMapper!.chapters;
    onChaptersReady?.call(chapters);
    _progressSaver.setHrefResolver(_chapterMapper!.indexForHref);
  }

  Future<void> _applyDecorations() async {
    if (_bookId.isEmpty) return;
    try {
      final pub = _session.publication;
      if (pub == null) return;
      final notes = await note_api.listNotesByBook(
        bookId: _bookId,
        noteType: NoteType.highlight,
      );
      final hrefMapping = <int, String>{};
      for (var i = 0; i < pub.readingOrder.length; i++) {
        hrefMapping[i] = pub.readingOrder[i].href;
      }
      final decorations = _decorationMapper.notesToDecorations(
        notes: notes,
        hrefMapping: hrefMapping,
        getChapterPlainText: (_) => '',
      );
      if (decorations.isNotEmpty) {
        await _session.applyDecorations('zephyr-highlights', decorations);
      }
    } catch (_) {
      // Silently ignore decoration failures.
    }
  }

  // ---------------------------------------------------------------
  // ReadingBackend interface
  // ---------------------------------------------------------------

  @override
  Future<void> open(ReadingOpenRequest request) async {
    try {
      _bookId = request.bookId;
      _progressSaver.setBookId(request.bookId);
      _emitSnapshot(ReadingStatus.opening);
      await _session.open(request.bookId);
      _emitSnapshot(ReadingStatus.ready);
    } catch (e) {
      _emitSnapshot(ReadingStatus.failed, errorMessage: e.toString());
      rethrow;
    }
  }

  @override
  Future<void> execute(ReadingCommand command) async {
    switch (command) {
      case PreviousPage():
        await _session.goLeft();
      case NextPage():
        await _session.goRight();
      case PreviousChapter():
        await _session.skipToPrevious();
      case NextChapter():
        await _session.skipToNext();
      case GoToChapter(:final chapterId):
        final idx = int.tryParse(chapterId);
        if (idx != null && _chapterMapper != null) {
          final href = _chapterMapper!.hrefForIndex(idx);
          if (href.isNotEmpty) {
            final pub = _session.publication;
            if (pub != null) {
              final link = pub.linkWithHref(href);
              if (link != null) {
                final locator = pub.locatorFromLink(link);
                if (locator != null) {
                  await _session.goToLocator(locator);
                }
              }
            }
          }
        }
      case GoToPosition(:final position):
        if (_chapterMapper == null) break;
        final href = _chapterMapper!.hrefForIndex(position.chapterIndex);
        if (href.isEmpty) break;
        final pub = _session.publication;
        if (pub == null) break;
        final link = pub.linkWithHref(href);
        if (link == null) break;
        final locator = pub.locatorFromLink(link);
        if (locator == null) break;
        await _session.goToLocator(locator);
    }
  }

  @override
  Future<void> applyPreferences(ReadingPreferences preferences) async {
    _prefsDebounce?.cancel();
    _prefsDebounce = Timer(const Duration(milliseconds: 200), () {
      unawaited(_applyPreferencesNow(preferences));
    });
  }

  Future<void> _applyPreferencesNow(ReadingPreferences prefs) async {
    try {
      final epubPrefs = _prefsMapper.toEpubPreferences(prefs);
      await _session.setEPUBPreferences(epubPrefs);
    } catch (e) {
      _emitSnapshot(ReadingStatus.failed,
          errorMessage: 'Preferences: ${e.toString()}');
    }
  }

  @override
  Future<void> close() async {
    _prefsDebounce?.cancel();
    await _progressSaver.flush();
    _progressSaver.dispose();
    await _session.close();
    _lastLocator = null;
  }

  // ---------------------------------------------------------------
  // Snapshot helper
  // ---------------------------------------------------------------

  void _emitSnapshot(
      ReadingStatus status, {
    double totalProgress = 0.0,
    String chapterTitle = '',
    String? errorMessage,
  }) {
    String title = '';
    if (_lastLocator != null && _lastLocator!.title != null) {
      title = _lastLocator!.title!;
    }
    snapshot.value = ReadingSnapshot(
      status: status,
      bookTitle: title,
      chapterTitle: chapterTitle,
      totalProgress: totalProgress,
      errorMessage: errorMessage,
    );
  }
}
