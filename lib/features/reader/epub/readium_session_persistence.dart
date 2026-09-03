import 'dart:async';
import 'dart:convert';

import 'package:flutter_readium/flutter_readium.dart';
import 'package:zephyr_reader/src/rust/api/book.dart' as book_api;
import 'package:zephyr_reader/src/rust/api/engine_position.dart'
    as engine_position_api;
import 'package:zephyr_reader/src/rust/api/progress.dart' as progress_api;
import 'package:zephyr_reader/src/rust/api/session.dart' as session_api;
import 'package:zephyr_reader/src/rust/domain/book/models.dart';
import 'package:zephyr_reader/src/rust/domain/engine_positions/models.dart';
import 'package:zephyr_reader/src/rust/domain/progress/models.dart';

import 'readium_session_tracker.dart';

typedef ProgressPersister = Future<void> Function(ReadingProgress progress);
typedef EnginePositionSaver =
    Future<void> Function({required EnginePositionHint hint});
typedef EnginePositionLoader =
    Future<EnginePositionHint?> Function({required String bookId});
typedef BookStatusUpdater =
    Future<void> Function({required String bookId, required BookStatus status});

Future<void> _defaultPersistProgress(ReadingProgress progress) =>
    progress_api.upsertProgress(progress: progress);

Future<void> _defaultSaveEnginePosition({required EnginePositionHint hint}) =>
    engine_position_api.saveEnginePosition(hint: hint);

Future<EnginePositionHint?> _defaultLoadEnginePosition({
  required String bookId,
}) => engine_position_api.getEnginePosition(bookId: bookId);

Future<void> _defaultUpdateBookStatus({
  required String bookId,
  required BookStatus status,
}) => book_api.updateBookStatus(bookId: bookId, status: status);

/// Owns the durable side effects of one Readium reading session.
///
/// The ViewModel supplies the current publication's coordinate rules and
/// receives errors through [onError]. Queueing, Locator restoration, progress
/// writes, engine hints, and session finalization stay behind this module's
/// small lifecycle surface.
class ReadiumSessionPersistence {
  ReadiumSessionPersistence({
    required this.bookId,
    required this.onError,
    required this.chapterIndexForHref,
    required this.charOffsetFor,
    required this.isActive,
    ProgressPersister? persistProgress,
    SessionRecorder? recordSession,
    EnginePositionSaver? saveEnginePosition,
    EnginePositionLoader? loadEnginePosition,
    BookStatusUpdater? updateBookStatus,
  }) : persistProgress = persistProgress ?? _defaultPersistProgress,
       recordSession = recordSession ?? _defaultRecordSession,
       saveEnginePosition = saveEnginePosition ?? _defaultSaveEnginePosition,
       loadEnginePosition = loadEnginePosition ?? _defaultLoadEnginePosition,
       updateBookStatus = updateBookStatus ?? _defaultUpdateBookStatus {
    _sessionTracker = ReadiumSessionTracker(
      bookId: bookId,
      recordSession: this.recordSession,
      chapterIndexForHref: chapterIndexForHref,
      charOffsetFor: charOffsetFor,
      isActive: isActive,
    );
  }

  final String bookId;
  final void Function(String message) onError;
  final int Function(String href) chapterIndexForHref;
  final int Function(Locator locator) charOffsetFor;
  final bool Function() isActive;
  final ProgressPersister persistProgress;
  final SessionRecorder recordSession;
  final EnginePositionSaver saveEnginePosition;
  final EnginePositionLoader loadEnginePosition;
  final BookStatusUpdater updateBookStatus;

  late final ReadiumSessionTracker _sessionTracker;
  Timer? _saveTimer;
  Future<void> _saveQueue = Future<void>.value();
  Locator? _currentLocator;
  String _publicationFingerprint = '';
  bool _lastIsCompleted = false;

  Locator? get currentLocator => _currentLocator;
  int? get currentChapterIndex => _sessionTracker.currentChapterIndex;

  void reset() {
    _currentLocator = null;
    _publicationFingerprint = '';
    _sessionTracker.reset();
  }

  void setPreviouslyCompleted(bool value) => _lastIsCompleted = value;

  void restoreLocator(Locator? locator) => _currentLocator = locator;

  Future<Locator?> loadSavedPosition({
    required String publicationFingerprint,
  }) async {
    _publicationFingerprint = publicationFingerprint;
    try {
      final hint = await loadEnginePosition(bookId: bookId);
      if (hint == null || hint.engineKind != 'readium') return null;
      if (hint.opaquePosition.isEmpty ||
          hint.publicationFingerprint.isEmpty ||
          hint.publicationFingerprint != _publicationFingerprint) {
        return null;
      }
      return Locator.fromJson(
        jsonDecode(hint.opaquePosition) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  void acceptLocator(Locator locator) {
    _currentLocator = locator;
    _sessionTracker.track(locator);
    _scheduleSave();
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    await _sessionTracker.finalize();
    await queueSave();
  }

  Future<void> finalizeSession() => _sessionTracker.finalize();

  Future<void> queueSave() {
    final next = _saveQueue.then((_) => _savePositionNow());
    _saveQueue = next;
    return next;
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () {
      unawaited(queueSave());
    });
  }

  Future<void> _savePositionNow() async {
    if (_currentLocator == null) return;
    await _saveReadingProgress();
  }

  Future<void> _saveReadingProgress() async {
    final locator = _currentLocator;
    if (locator == null) return;
    final totalProgression = locator.locations?.totalProgression ?? 0.0;
    final isCompleted = totalProgression >= 0.999;
    try {
      await persistProgress(
        ReadingProgress(
          bookId: bookId,
          chapterIndex: chapterIndexForHref(locator.href),
          chunkIndex: 0,
          chapterId: locator.href,
          charOffset: charOffsetFor(locator),
          progress: totalProgression,
          // Reading duration is aggregated from reading_sessions.
          readingTimeSeconds: 0,
          lastReadAt: DateTime.now().toUtc(),
          isCompleted: isCompleted,
        ),
      );
      if (isCompleted && !_lastIsCompleted) {
        _lastIsCompleted = true;
        try {
          await updateBookStatus(bookId: bookId, status: BookStatus.completed);
        } catch (e) {
          onError('标记阅读完成失败：$e');
        }
      }
    } catch (e) {
      onError('保存阅读进度失败：$e');
    }

    try {
      await saveEnginePosition(
        hint: EnginePositionHint(
          bookId: bookId,
          engineKind: 'readium',
          publicationFingerprint: _publicationFingerprint,
          opaquePosition: jsonEncode(locator.toJson()),
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    } catch (e) {
      onError('保存阅读位置失败：$e');
    }
  }
}

Future<void> _defaultRecordSession({
  required String bookId,
  required int chapterIndex,
  required int startedAt,
  required int durationSeconds,
}) async {
  await session_api.createSession(
    bookId: bookId,
    chapterIndex: chapterIndex,
    startedAt: startedAt,
    durationSeconds: durationSeconds,
  );
}
