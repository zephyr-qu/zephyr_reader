import 'package:flutter/foundation.dart';
import 'reading_backend_kind.dart';
import 'reading_capabilities.dart';
import 'reading_command.dart';
import 'reading_open_request.dart';
import 'reading_snapshot.dart';
import '../preferences/reading_preferences.dart';

/// Abstract interface for a reading backend.
///
/// Each backend implements one engine (Builtin or Readium). The UI layer
/// interacts only through this seam — it never imports engine-specific
/// packages (flureadium, ReaderViewModel, etc.).
abstract interface class ReadingBackend {
  /// Which engine this backend represents.
  ReadingBackendKind get kind;

  /// What this backend is capable of.
  ReadingCapabilities get capabilities;

  /// Observable atomic reading state snapshot.
  ///
  /// The UI subscribes to this single source of truth rather than
  /// subscribing to multiple signals that may go out of sync.
  ValueListenable<ReadingSnapshot> get snapshot;

  /// Open a book and prepare for reading.
  Future<void> open(ReadingOpenRequest request);

  /// Execute a navigation command.
  Future<void> execute(ReadingCommand command);

  /// Apply reader preferences (font size, theme, scroll mode, etc.).
  Future<void> applyPreferences(ReadingPreferences preferences);

  /// Close the current book and release all resources.
  ///
  /// Must be idempotent — calling close() multiple times is safe.
  /// After close(), the backend should not emit further events.
  Future<void> close();
}

