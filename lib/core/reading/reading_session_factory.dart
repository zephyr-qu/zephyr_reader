import 'backend/reading_backend_kind.dart';
import 'backend/reading_backend_policy.dart';
import 'backend/reading_open_request.dart';
import 'backend/readium/readium_reading_backend.dart';
import 'backend/readium/readium_reading_viewport.dart';
import 'backend/readium/readium_session.dart';
import 'reading_session.dart';
import 'reader_feature_coordinator.dart';

/// Factory interface for creating a Builtin reading backend + viewport.
///
/// Concrete implementation is wired at the DI level to avoid importing
/// ReaderViewModel in the core seam layer.
abstract class BuiltinBackendFactory {
  ReadingSession create(ReadingOpenRequest request);
}

/// Scoped reading session with multi-backend support.
class ReadingSessionFactory {
  final ReadingBackendPolicy policy;
  final BuiltinBackendFactory builtinFactory;

  /// Resolve a book's file path from its ID.
  final String Function(String bookId) filePathResolver;

  ReadingSessionFactory({
    required this.policy,
    required this.builtinFactory,
    required this.filePathResolver,
  });

  /// Create a scoped [ReadingSession] for the given [request].
  Future<ReadingSession> create(ReadingOpenRequest request) async {
    final kind = policy.select(format: request.format, bookId: request.bookId);

    switch (kind) {
      case ReadingBackendKind.builtin:
        return builtinFactory.create(request);
      case ReadingBackendKind.readium:
        return _createReadiumSession(request);
    }
  }

  ReadingSession _createReadiumSession(ReadingOpenRequest request) {
    final filePath = filePathResolver(request.bookId);
    final rwSession = ReadiumSession();
    final backend = ReadiumReadingBackend(session: rwSession);
    final viewport = ReadiumReadingViewport(
      session: rwSession,
      filePath: filePath,
    );
    final coordinator = ReaderFeatureCoordinator();

    // Wire chapters into the session when the mapper is ready.
    late final ReadingSession session;
    session = ReadingSession(
      backend: backend,
      viewport: viewport,
      features: coordinator,
    );
    backend.onChaptersReady = (chapters) {
      session.chapters = chapters;
    };
    return session;
  }
}
