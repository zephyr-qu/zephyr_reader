import 'reading_backend_kind.dart';

/// Strategy for selecting the appropriate reading backend for a book.
///
/// ## Priority (highest to lowest)
/// 1. Per-book explicit preference (`bookId → ReadingBackendKind`)
/// 2. Global strategy (Readium for EPUB, Builtin for TXT)
/// 3. Platform Readium support
/// 4. Readium failure history for this book
/// 5. Default Builtin
///
/// All decisions are centralized here — the UI must never write
/// `if (book.format == epub)` to choose a backend.
class ReadingBackendPolicy {
  /// Per-book overrides: bookId → preferred backend kind.
  final Map<String, ReadingBackendKind> _perBookOverrides = {};

  /// Whether Readium support is available on this platform.
  bool _readiumAvailable = true;

  /// Set of book IDs where Readium has previously failed to open.
  final Set<String> _readiumFailedBooks = {};

  // ---------------------------------------------------------------
  // Query
  // ---------------------------------------------------------------

  /// Select the backend kind for the given book format and ID.
  ///
  /// [format] should be `'epub'`, `'txt'`, etc.
  ReadingBackendKind select({required String format, required String bookId}) {
    // 1. Per-book override
    if (_perBookOverrides.containsKey(bookId)) {
      return _perBookOverrides[bookId]!;
    }

    // 2-4. Format-based with platform gate and failure history
    if (format == 'epub' &&
        _readiumAvailable &&
        !_readiumFailedBooks.contains(bookId)) {
      return ReadingBackendKind.readium;
    }

    // 5. Default Builtin (handles TXT, unknown formats, or EPUB when Readium fails)
    return ReadingBackendKind.builtin;
  }

  /// Whether a per-book override exists for the given book.
  bool hasOverride(String bookId) => _perBookOverrides.containsKey(bookId);

  // ---------------------------------------------------------------
  // Mutation — per-book overrides
  // ---------------------------------------------------------------

  /// Set a per-book backend override.
  void setPerBookOverride(String bookId, ReadingBackendKind kind) {
    _perBookOverrides[bookId] = kind;
    // Also clear failure record so the new choice gets a fresh start.
    _readiumFailedBooks.remove(bookId);
  }

  /// Clear a per-book override (revert to default policy).
  void clearPerBookOverride(String bookId) {
    _perBookOverrides.remove(bookId);
  }

  // ---------------------------------------------------------------
  // Mutation — failure tracking
  // ---------------------------------------------------------------

  /// Record that Readium failed to open this book.
  ///
  /// Subsequent `select()` calls for this book will prefer Builtin
  /// until the failure record is cleared or an override is set.
  void recordReadiumFailure(String bookId) {
    _readiumFailedBooks.add(bookId);
  }

  /// Clear the Readium failure record for this book.
  ///
  /// Used after a manual "retry with Readium" action.
  void clearReadiumFailure(String bookId) {
    _readiumFailedBooks.remove(bookId);
  }

  // ---------------------------------------------------------------
  // Mutation — platform availability
  // ---------------------------------------------------------------

  /// Update whether Readium is available on this platform.
  ///
  /// On platforms where Readium is not supported (e.g. web without the
  /// native plugin), set this to `false` to always use Builtin.
  void setReadiumAvailability(bool available) {
    _readiumAvailable = available;
  }
}
