/// Engine-agnostic chapter info for the unified TOC and navigation.
///
/// Both Builtin and Readium backends produce this from their own
/// data sources (Builtin: Rust Chapter rows; Readium: Publication
/// readingOrder / tableOfContents). The TOC UI consumes only this
/// model — it never touches engine-specific chapter types.
class ReadingChapter {
  /// Unique identifier within the book.
  final String id;

  /// Zero-based index in the book's chapter sequence.
  final int index;

  /// Human-readable chapter title.
  final String title;

  /// Raw href / resource path (Readium only — empty for Builtin).
  ///
  /// For Readium EPUBs this is the `Link.href` used with goToLocator.
  final String href;

  const ReadingChapter({
    required this.id,
    required this.index,
    required this.title,
    this.href = '',
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadingChapter &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          index == other.index &&
          title == other.title &&
          href == other.href;

  @override
  int get hashCode => Object.hash(runtimeType, id, index, title, href);

  @override
  String toString() =>
      'ReadingChapter(id:$id, index:$index, title:$title, href:$href)';
}
