/// Precision level of a position mapping result.
///
/// Used when converting from an engine-specific locator to a
/// [ReadingPosition] — not all conversions yield exact offsets.
enum PositionPrecision {
  /// The position was derived from an exact text match.
  /// Example: Locator quote was found in plainText at a unique location.
  exact,

  /// The position was derived from context around the match.
  /// Example: quote found in multiple locations, best match chosen
  /// using nearby context.
  contextual,

  /// The position was estimated from progression/percentage.
  /// Example: text quote not found, fell back to `totalProgression`
  /// within the chapter.
  approximate,
}
