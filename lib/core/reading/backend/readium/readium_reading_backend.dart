import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flureadium/flureadium.dart';

import '../reading_backend.dart';
import '../reading_backend_kind.dart';
import '../reading_capabilities.dart';
import '../reading_command.dart';
import '../reading_open_request.dart';
import '../reading_snapshot.dart';
import '../reading_status.dart';
import '../../preferences/reading_preferences.dart';
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

  ReadiumReadingBackend({
    ReadiumSession? session,
  }) : _session = session ?? ReadiumSession(),
       snapshot = ValueNotifier<ReadingSnapshot>(ReadingSnapshot.closed) {
    _setupCallbacks();
  }

  void _setupCallbacks() {
    // State changes from the session are forwarded to the snapshot.
    _session.onStateChanged = (state) {
      switch (state) {
        case ReadiumSessionState.idle:
          _emitSnapshot(ReadingStatus.closed);
        case ReadiumSessionState.opening:
          _emitSnapshot(ReadingStatus.opening);
        case ReadiumSessionState.ready:
          _emitSnapshot(ReadingStatus.ready);
        case ReadiumSessionState.failed:
          _emitSnapshot(ReadingStatus.failed, errorMessage: 'Session failed');
      }
    };

    // Track locator updates from the native viewport.
    _session.onLocatorChanged = (locator) {
      _lastLocator = locator;
      _emitSnapshot(ReadingStatus.ready,
          totalProgress: locator.locations?.totalProgression ?? 0.0);
    };

    // Forward errors.
    _session.onError = (message) {
      _emitSnapshot(ReadingStatus.failed, errorMessage: message);
    };
  }

  // ---------------------------------------------------------------
  // ReadingBackend interface
  // ---------------------------------------------------------------

  @override
  Future<void> open(ReadingOpenRequest request) async {
    try {
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
      case GoToChapter():
        // Requires chapter mapper (R6). Use skipToNext/Previous for now.
        break;
      case GoToPosition():
        // Requires position bridge (R6).
        break;
    }
  }

  @override
  Future<void> applyPreferences(ReadingPreferences preferences) async {
    final epubPrefs = _toEpubPreferences(preferences);
    await _session.setEPUBPreferences(epubPrefs);
  }

  @override
  Future<void> close() async {
    await _session.close();
    _lastLocator = null;
  }

  // ---------------------------------------------------------------
  // Preference mapping
  // ---------------------------------------------------------------

  EPUBPreferences _toEpubPreferences(ReadingPreferences prefs) {
    return EPUBPreferences(
      fontFamily: prefs.fontFamily ?? 'Original',
      fontSize: prefs.fontSize.toInt(),
      fontWeight: 400,
      backgroundColor: _themeBg(prefs.theme),
      textColor: _themeFg(prefs.theme),
      pageMargins: prefs.pageMargin,
      verticalScroll: prefs.readingMode == 'scroll',
    );
  }

  Color _themeBg(String theme) {
    switch (theme) {
      case 'sepia':
        return const Color(0xFFF5E6D3);
      case 'dark':
        return const Color(0xFF1A1A2E);
      default:
        return const Color(0xFFFFFFFF);
    }
  }

  Color _themeFg(String theme) {
    switch (theme) {
      case 'sepia':
        return const Color(0xFF3E2723);
      case 'dark':
        return const Color(0xFFE0E0E0);
      default:
        return const Color(0xFF000000);
    }
  }

  // ---------------------------------------------------------------
  // Snapshot helper
  // ---------------------------------------------------------------

  void _emitSnapshot(
    ReadingStatus status, {
    double totalProgress = 0.0,
    String? errorMessage,
  }) {
    String title = '';
    if (_lastLocator != null && _lastLocator!.title != null) {
      title = _lastLocator!.title!;
    }
    snapshot.value = ReadingSnapshot(
      status: status,
      bookTitle: title,
      chapterTitle: '',
      totalProgress: totalProgress,
      errorMessage: errorMessage,
    );
  }
}
