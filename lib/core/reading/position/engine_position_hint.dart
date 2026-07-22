import '../backend/reading_backend_kind.dart';

/// Engine-specific position hint for fast restoration.
///
/// This is NOT the domain truth for position. It is an opaque hint
/// stored alongside [ReadingPosition] to speed up restoration in the
/// engine that produced it.
///
/// ## Rules
/// - Locator not matching the current publication fingerprint must be discarded
/// - Builtin must never read Readium position hints
/// - If engine kind doesn't match the current backend, the hint is ignored
class EnginePositionHint {
  /// Which engine created this hint.
  final ReadingBackendKind engineKind;

  /// Fingerprint of the EPUB publication at the time the hint was saved.
  ///
  /// Used to detect file changes. When the fingerprint changes, the
  /// hint must be discarded and a logical position fallback used instead.
  final String publicationFingerprint;

  /// Opaque engine-specific position data.
  ///
  /// For Readium, this is a serialized Locator JSON string.
  /// For Builtin, this is null/empty (not used).
  final String opaquePosition;

  const EnginePositionHint({
    required this.engineKind,
    required this.publicationFingerprint,
    required this.opaquePosition,
  });
}
