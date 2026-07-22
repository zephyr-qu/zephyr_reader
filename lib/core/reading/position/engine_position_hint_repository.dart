import '../../../src/rust/api/engine_position.dart' as frb;
import '../../../src/rust/domain/engine_position/models.dart';
import '../backend/reading_backend_kind.dart';
import 'engine_position_hint.dart';

/// Repository for engine-specific position hints.
///
/// Callers should always validate the returned hint against the
/// current publication fingerprint before using it for restoration.
///
/// Builtin backend must never call this repository for Readium hints.
class EnginePositionHintRepository {
  /// Save an engine position hint for the given book.
  Future<void> save({
    required String bookId,
    required EnginePositionHint hint,
  }) {
    return frb.saveEnginePositionHint(
      position: ReadingEnginePosition(
        bookId: bookId,
        engineKind: hint.engineKind.name,
        publicationFingerprint: hint.publicationFingerprint,
        opaquePosition: hint.opaquePosition,
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Load the engine position hint for the given book.
  ///
  /// Returns null when no hint exists or when loading fails.
  Future<EnginePositionHint?> load(String bookId) async {
    final result = await frb.getEnginePositionHint(bookId: bookId);
    if (result == null) return null;

    return EnginePositionHint(
      engineKind: _parseBackendKind(result.engineKind),
      publicationFingerprint: result.publicationFingerprint,
      opaquePosition: result.opaquePosition,
    );
  }

  /// Delete the engine position hint for the given book.
  Future<void> delete(String bookId) {
    return frb.deleteEnginePositionHint(bookId: bookId);
  }

  ReadingBackendKind _parseBackendKind(String kind) {
    switch (kind) {
      case 'builtin':
        return ReadingBackendKind.builtin;
      case 'readium':
        return ReadingBackendKind.readium;
      default:
        return ReadingBackendKind.readium;
    }
  }
}
