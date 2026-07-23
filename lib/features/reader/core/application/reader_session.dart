import 'package:zephyr_reader/core/reader_engine/shared/config/reader_config.dart';
import 'package:zephyr_reader/features/reader/core/application/reader_view_model.dart';
import 'package:zephyr_reader/core/reader_engine/data/chapter_content_repository.dart';
import 'package:zephyr_reader/features/reader/domain/progress_repository.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/engine.dart';

/// Per-book reading session — owns a dedicated [ReaderViewModel] instance.
class ReaderSession {
  final ReaderViewModel vm;

  ReaderSession(this.vm);

  Future<void> dispose() => vm.resetForNewBook();
}


/// Creates scoped [ReaderSession] instances.
///

/// Creates scoped [ReaderSession] instances.
class ReaderSessionFactory {
  final ChapterContentRepository _chapterContent;
  final ProgressRepository _progress;
  final ReaderConfig _config;

  ReaderSessionFactory(
    this._chapterContent,
    this._progress,
    this._config,
  );

  ReaderSession create() {
    final engine = PaginationEngine(_chapterContent);
    final vm = ReaderViewModel(
      contentRepo: _chapterContent,
      engine: engine,
      progressRepo: _progress,
      config: _config,
    );
    return ReaderSession(vm);
  }
}
