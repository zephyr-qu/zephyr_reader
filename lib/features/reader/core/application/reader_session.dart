import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/features/reader/core/application/reader_view_model.dart';
import 'package:zephyr_reader/features/reader/core/data/pagination_session_factory.dart';
import 'package:zephyr_reader/features/reader/core/domain/chapter_content_repository.dart';
import 'package:zephyr_reader/features/reader/core/domain/progress_repository.dart';
import 'package:zephyr_reader/features/reader/data/repositories/rust_reader_repository.dart';

/// Per-book reading session — owns a dedicated [ReaderViewModel] instance.
class ReaderSession {
  final ReaderViewModel vm;

  ReaderSession(this.vm);

  Future<void> dispose() => vm.resetForNewBook();
}

/// Creates scoped [ReaderSession] instances with dedicated [ReaderRepository].
@injectable
class ReaderSessionFactory {
  final ChapterContentRepository _chapterContent;
  final ProgressRepository _progress;
  final PaginationSessionFactory _sessionFactory;
  final ReaderConfig _config;

  ReaderSessionFactory(
    this._chapterContent,
    this._progress,
    this._sessionFactory,
    this._config,
  );

  ReaderSession create() {
    final repo = ReaderRepository(_chapterContent, _progress, _sessionFactory);
    return ReaderSession(ReaderViewModel(repo: repo, config: _config));
  }
}
