import 'reading_backend_kind.dart';

/// Strategy for selecting the appropriate reading backend for a given book.
///
/// ## Priority (highest to lowest)
/// 1. Per-book explicit preference (`bookId → ReadingBackendKind`)
/// 2. Global EPUB strategy (Readium for EPUB, Builtin for TXT)
/// 3. Platform support for Readium
/// 4. Readium failure history for this book
/// 5. Default Builtin
///
/// Skeleton — completed and refined in R7.
class ReadingBackendPolicy {
  /// Per-book overrides: bookId → preferred backend kind.
  final Map<String, ReadingBackendKind> perBookOverrides;

  /// Whether Readium support is available on this platform.
  final bool readiumAvailable;

  /// Set of book IDs where Readium has previously failed to open.
  final Set<String> readiumFailedBooks;

  const ReadingBackendPolicy({
    this.perBookOverrides = const {},
    this.readiumAvailable = true,
    this.readiumFailedBooks = const {},
  });

  /// Select the backend kind for the given book format and book ID.
  ReadingBackendKind select({required String format, required String bookId}) {
    // 1. Per-book override
    if (perBookOverrides.containsKey(bookId)) {
      return perBookOverrides[bookId]!;
    }

    // 2, 3. Format-based selection with platform gate
    if (format == 'epub' &&
        readiumAvailable &&
        !readiumFailedBooks.contains(bookId)) {
      return ReadingBackendKind.readium;
    }

    // 5. Default
    return ReadingBackendKind.builtin;
  }
}
