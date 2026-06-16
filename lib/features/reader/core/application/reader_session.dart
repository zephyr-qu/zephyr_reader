import 'package:injectable/injectable.dart';
import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/features/reader/core/application/reader_view_model.dart';
import 'package:zephyr_reader/features/reader/data/repositories/rust_reader_repository.dart';

/// Per-book reading session — owns a dedicated [ReaderViewModel] instance.
class ReaderSession {
  final ReaderViewModel vm;

  ReaderSession(this.vm);

  Future<void> dispose() => vm.resetForNewBook();
}

/// Creates scoped [ReaderSession] instances (not singleton).
@injectable
class ReaderSessionFactory {
  final ReaderRepository _repo;
  final ReaderConfig _config;

  ReaderSessionFactory(this._repo, this._config);

  ReaderSession create() => ReaderSession(
    ReaderViewModel(repo: _repo, config: _config),
  );
}
