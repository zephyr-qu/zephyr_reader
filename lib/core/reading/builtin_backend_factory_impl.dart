import 'package:zephyr_reader/core/reader_engine/data/chapter_content_repository.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/engine.dart';
import 'package:zephyr_reader/core/reader_engine/shared/config/reader_config.dart';
import 'package:zephyr_reader/di/service_locator.dart';
import 'package:zephyr_reader/features/reader/core/application/reader_view_model.dart';
import 'package:zephyr_reader/features/reader/domain/progress_repository.dart';
import 'backend/builtin/builtin_reading_backend.dart';
import 'backend/placeholder_viewport.dart';
import 'backend/reading_open_request.dart';
import 'reader_feature_coordinator.dart';
import 'reading_session.dart';
import 'reading_session_factory.dart';

/// Concrete implementation of [BuiltinBackendFactory].
///
/// Creates a [BuiltinReadingBackend] wrapping the existing
/// [ReaderViewModel] infrastructure. The viewport is a placeholder
/// — the shell replaces it with a real [BuiltinReadingViewport]
/// carrying UI-scoped signals (vocab words, selection position).
class BuiltinBackendFactoryImpl implements BuiltinBackendFactory {
  @override
  ReadingSession create(ReadingOpenRequest request) {
    final contentRepo = getIt<ChapterContentRepository>();
    final progressRepo = getIt<ProgressRepository>();
    final config = getIt<ReaderConfig>();
    final engine = PaginationEngine(contentRepo);
    final vm = ReaderViewModel(
      contentRepo: contentRepo,
      engine: engine,
      progressRepo: progressRepo,
      config: config,
    );
    final backend = BuiltinReadingBackend(viewModel: vm);
    final coordinator = ReaderFeatureCoordinator();

    // Wire chapters into the session when they become available.
    final ReadingSession session = ReadingSession(
      backend: backend,
      viewport: const PlaceholderViewport(),
      features: coordinator,
    );
    backend.onChaptersReady = (chapters) {
      session.chapters = chapters;
    };
    return session;
  }
}
