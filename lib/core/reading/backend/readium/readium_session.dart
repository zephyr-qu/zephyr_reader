import 'dart:async';
import 'package:flureadium/flureadium.dart';

/// Readium session — manages a single book's reading lifecycle.
///
/// Each book conceptually gets its own session scope, though the
/// underlying [Flureadium] instance is a singleton by design.
///
/// ## Open generation
/// Every `open()` call increments a generation counter. Async callbacks
/// from an older generation are silently discarded when a newer one is
/// active. This prevents stale callbacks from a previously opened book
/// from firing during the current session.
class ReadiumSession {
  // ---------------------------------------------------------------
  // State
  // ---------------------------------------------------------------

  ReadiumSessionState _state = ReadiumSessionState.idle;
  ReadiumSessionState get state => _state;
  bool get isReady => _state == ReadiumSessionState.ready;

  /// Incremented on each open() call.
  int _openGeneration = 0;

  /// The singleton Flureadium reader instance.
  late final Flureadium _reader = Flureadium();

  /// The current open publication (used by chapter mapper).
  Publication? get publication => _publication;
  Publication? _publication;

  // ---------------------------------------------------------------
  // Stream subscriptions
  // ---------------------------------------------------------------

  StreamSubscription<Locator>? _locatorSub;
  StreamSubscription<ReadiumReaderStatus>? _statusSub;
  StreamSubscription<ReadiumError>? _errorSub;

  // ---------------------------------------------------------------
  // Callbacks
  // ---------------------------------------------------------------

  void Function(Locator locator)? onLocatorChanged;
  void Function()? onReaderReady;
  void Function(String message)? onError;
  void Function(ReadiumSessionState state)? onStateChanged;

  // ---------------------------------------------------------------
  // Current position
  // ---------------------------------------------------------------

  /// Latest Locator received from the native viewport.
  Locator? currentLocator;

  // ---------------------------------------------------------------
  // Open
  // ---------------------------------------------------------------

  /// Opens a publication at the given [path].
  ///
  /// Returns the [Publication] once opened, or throws on failure.
  /// The caller should catch and handle errors.
  Future<Publication> open(String path) async {
    final generation = ++_openGeneration;
    _state = ReadiumSessionState.opening;
    onStateChanged?.call(_state);

    _cancelSubscriptions();

    try {
      final uriPath = path.startsWith('file://')
          ? path
          : Uri.file(path, windows: true).toString();

      _setupSubscriptions(generation);

      final pub = await _reader.openPublication(uriPath);

      if (generation != _openGeneration) {
        unawaited(_closeInternal());
        throw ReadiumSessionCancelledException();
      }

      _publication = pub;
      return pub;
    } catch (e) {
      if (e is ReadiumSessionCancelledException) rethrow;
      _state = ReadiumSessionState.failed;
      onStateChanged?.call(_state);
      onError?.call(e.toString());
      rethrow;
    }
  }

  // ---------------------------------------------------------------
  // Viewport readiness
  // ---------------------------------------------------------------

  /// Called by the viewport when the native Platform View is initialized.
  void signalViewportReady() {
    if (_state == ReadiumSessionState.opening) {
      _state = ReadiumSessionState.ready;
      onReaderReady?.call();
      onStateChanged?.call(_state);
    }
  }

  // ---------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------

  Future<void> goLeft() => _guardFuture(_reader.goLeft());
  Future<void> goRight() => _guardFuture(_reader.goRight());
  Future<void> skipToNext() => _guardFuture(_reader.skipToNext());
  Future<void> skipToPrevious() => _guardFuture(_reader.skipToPrevious());

  /// Navigate to a specific [Locator]. Returns true if successful.
  Future<bool> goToLocator(Locator locator) async {
    if (!isReady) return false;
    try {
      return await _reader.goToLocator(locator);
    } catch (e) {
      onError?.call(e.toString());
      return false;
    }
  }

  // ---------------------------------------------------------------
  // Preferences
  // ---------------------------------------------------------------

  /// Apply EPUB visual preferences.
  Future<void> setEPUBPreferences(EPUBPreferences preferences) =>
      _guardFuture(_reader.setEPUBPreferences(preferences));

  // ---------------------------------------------------------------
  // Decorations
  // ---------------------------------------------------------------

  Future<void> applyDecorations(
    String id,
    List<ReaderDecoration> decorations,
  ) => _guardFuture(_reader.applyDecorations(id, decorations));

  // ---------------------------------------------------------------
  // Close (idempotent)
  // ---------------------------------------------------------------

  Future<void> close() async {
    if (_state == ReadiumSessionState.idle) return;
    await _closeInternal();
  }

  Future<void> _closeInternal() async {
    _openGeneration++;
    _cancelSubscriptions();
    try {
      await _reader.closePublication();
    } catch (_) {
      // Swallow errors during close.
    }
    _publication = null;
    currentLocator = null;
    _state = ReadiumSessionState.idle;
    onStateChanged?.call(_state);
  }

  // ---------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------

  void _setupSubscriptions(int generation) {
    _locatorSub = _reader.onTextLocatorChanged.listen((locator) {
      if (generation != _openGeneration) return;
      currentLocator = locator;
      onLocatorChanged?.call(locator);
    });

    _statusSub = _reader.onReaderStatusChanged.listen((status) {
      if (generation != _openGeneration) return;
      if (status == ReadiumReaderStatus.ready &&
          _state == ReadiumSessionState.opening) {
        _state = ReadiumSessionState.ready;
        onReaderReady?.call();
        onStateChanged?.call(_state);
      }
    });

    _errorSub = _reader.onErrorEvent.listen((e) {
      if (generation != _openGeneration) return;
      final message = e.toString();
      onError?.call(message);
    });
  }

  void _cancelSubscriptions() {
    unawaited(_locatorSub?.cancel());
    _locatorSub = null;
    unawaited(_statusSub?.cancel());
    _statusSub = null;
    unawaited(_errorSub?.cancel());
    _errorSub = null;
  }

  Future<void> _guardFuture(Future<void> call) async {
    if (!isReady) return;
    try {
      await call;
    } catch (e) {
      onError?.call(e.toString());
    }
  }
}

// ---------------------------------------------------------------
// Supporting types
// ---------------------------------------------------------------

enum ReadiumSessionState { idle, opening, ready, failed }

class ReadiumSessionCancelledException implements Exception {
  @override
  String toString() =>
      'ReadiumSessionCancelledException: '
      'Operation cancelled by newer open() call.';
}
