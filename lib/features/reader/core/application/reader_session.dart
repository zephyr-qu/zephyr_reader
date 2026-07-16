import 'package:zephyr_reader/features/reader/domain/bilingual_reader_delegate.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_view_model.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/features/reader/core/application/reader_view_model.dart';
import 'package:zephyr_reader/features/reader/domain/chapter_content_repository.dart';
import 'package:zephyr_reader/features/reader/domain/progress_repository.dart';
import 'package:zephyr_reader/features/reader/core/data/default_reader_render_data_source.dart';
import 'package:zephyr_reader/reader_engine/pagination/flutter_pagination_session.dart';

/// Per-book reading session — owns a dedicated [ReaderViewModel] instance.
class ReaderSession {
  final ReaderViewModel vm;

  ReaderSession(this.vm);

  Future<void> dispose() => vm.resetForNewBook();
}

/// 双语 delegate 工厂签名。由 DI 层注入，接受 [ChapterViewModel] 返回 delegate。
typedef BilingualReaderDelegateFactory =
    BilingualReaderDelegate? Function(ChapterViewModel chapterVM);

/// Creates scoped [ReaderSession] instances.
///
/// [_bilingualFactory] 可选；提供时在 [create] 时注入 [BilingualReaderDelegate] 到
/// [ReaderViewModel.bilingual]，用于双语解耦的 DI 收口。
class ReaderSessionFactory {
  final ChapterContentRepository _chapterContent;
  final ProgressRepository _progress;
  final ReaderConfig _config;
  final BilingualReaderDelegateFactory? _bilingualFactory;

  ReaderSessionFactory(
    this._chapterContent,
    this._progress,
    this._config, [
    this._bilingualFactory,
  ]);

  ReaderSession create() {
    final session = PaginationSession(
      onCacheUpdated: () => _chapterContent.preloadGeneration.value++,
    );
    final dataSource = DefaultReaderRenderDataSource(_chapterContent, session);
    final vm = ReaderViewModel(
      contentRepo: _chapterContent,
      session: session,
      progressRepo: _progress,
      dataSource: dataSource,
      config: _config,
    );
    final bilingualFactory = _bilingualFactory;
    if (bilingualFactory != null) {
      vm.bilingual = bilingualFactory(vm.chapterManager);
    }
    return ReaderSession(vm);
  }
}
