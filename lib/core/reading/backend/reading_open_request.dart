/// Request parameters for opening a book in a reading backend.
class ReadingOpenRequest {
  /// Unique identifier of the book to open.
  final String bookId;

  /// Format hint for the backend to select the appropriate reader.
  final String format;

  /// Optional chapter index to restore to.
  final int? restoreChapterIndex;

  /// Optional character offset within the chapter to restore to.
  final int? restoreCharOffset;

  const ReadingOpenRequest({
    required this.bookId,
    required this.format,
    this.restoreChapterIndex,
    this.restoreCharOffset,
  });
}
