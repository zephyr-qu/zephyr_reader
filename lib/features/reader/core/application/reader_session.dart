import 'package:zephyr_reader/features/bilingual/application/bilingual_view_model.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_view_model.dart';
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

/// 双语工厂签名。接受 [ChapterViewModel] 返回 [BilingualViewModel]。
typedef BilingualViewModelFactory =
    BilingualViewModel? Function(ChapterViewModel chapterVM);

/// Creates scoped [ReaderSession] instances.
///
/// [_bilingualFactory] 可选；提供时在 [create] 时注入 [BilingualViewModel] 到
/// [ReaderViewModel.bilingual]。
class ReaderSessionFactory {
  final ChapterContentRepository _chapterContent;
  final ProgressRepository _progress;
  final ReaderConfig _config;
  final BilingualViewModelFactory? _bilingualFactory;

  ReaderSessionFactory(
    this._chapterContent,
    this._progress,
    this._config, [
    this._bilingualFactory,
  ]);

  ReaderSession create() {
    final engine = PaginationEngine(_chapterContent);
    final vm = ReaderViewModel(
      contentRepo: _chapterContent,
      engine: engine,
      progressRepo: _progress,
      config: _config,
    );
    final bilingualFactory = _bilingualFactory;
    if (bilingualFactory != null) {
      vm.bilingual = bilingualFactory(vm.chapterManager);
    }
    return ReaderSession(vm);
  }
}
