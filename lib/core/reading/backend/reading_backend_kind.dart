/// Kind of reading backend engine.
enum ReadingBackendKind {
  /// Builtin self-developed engine (Rust IR → Flutter TextPainter).
  /// Supports TXT and EPUB (fallback).
  builtin,

  /// Readium engine via flureadium.
  /// Supports EPUB (primary).
  readium,
}
