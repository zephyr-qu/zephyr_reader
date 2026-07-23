import 'backend/reading_backend.dart';
import 'backend/reading_viewport_adapter.dart';
import 'chapter/reading_chapter.dart';
import 'reader_feature_coordinator.dart';

/// A scoped reading session holding one book's backend, viewport, and
/// engine-agnostic features.
///
/// Each book gets its own [ReadingSession]. When the session is
/// disposed, both backend and viewport resources are released.
/// DI must never expose a singleton Flureadium — each Readium session
/// manages its own subscription lifecycle.
class ReadingSession {
  /// The engine-specific backend for this book.
  final ReadingBackend backend;

  /// The viewport adapter for this book's engine.
  ///
  /// Mutable: the shell may override the viewport after construction
  /// when UI-scoped signals are needed (e.g. Builtin's vocab signals,
  /// selection position). The factory creates a basic viewport; the
  /// shell replaces it with a context-aware one before first build.
  ReadingViewportAdapter viewport;
  /// Engine-agnostic features (timer, auto-save, bookmarks, etc.).
  final ReaderFeatureCoordinator features;

  /// Chapters for TOC navigation, populated by the backend.
  List<ReadingChapter> chapters = const [];

  ReadingSession({
    required this.backend,
    required this.viewport,
    ReaderFeatureCoordinator? features,
  }) : features = features ?? ReaderFeatureCoordinator();

  /// Close the backend and release all resources.
  ///
  /// After calling this, the session should not be used again.
  Future<void> dispose() async {
    await features.dispose();
    await backend.close();
  }
}
