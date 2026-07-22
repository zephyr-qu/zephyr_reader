/// Logical reading position within a book.
///
/// This is the **domain truth** for progress, bookmarks, notes, search
/// results, and TTS — across both engines. Readium Locator is stored
/// separately as an [EnginePositionHint] for fast restoration.
class ReadingPosition {
  /// Zero-based index of the chapter.
  final int chapterIndex;

  /// UTF-16 code unit offset within the chapter's plain text.
  ///
  /// This matches the [String.codeUnitAt] semantics used by
  /// Flutter and FRB. See ADR-017.
  final int charOffsetUtf16;

  const ReadingPosition({
    required this.chapterIndex,
    required this.charOffsetUtf16,
  });

  /// The minimum possible position (start of chapter 0).
  static const zero = ReadingPosition(chapterIndex: 0, charOffsetUtf16: 0);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadingPosition &&
          runtimeType == other.runtimeType &&
          chapterIndex == other.chapterIndex &&
          charOffsetUtf16 == other.charOffsetUtf16;

  @override
  int get hashCode => Object.hash(runtimeType, chapterIndex, charOffsetUtf16);

  @override
  String toString() =>
      'ReadingPosition(chapter:$chapterIndex, offset:$charOffsetUtf16)';
}
