import 'package:zephyr_reader/features/reader/domain/chapter_content_repository.dart';
import 'package:zephyr_reader/reader_engine/pagination/flutter_pagination_session.dart';
import 'package:zephyr_reader/reader_engine/pagination/packed_page.dart';
import 'package:zephyr_reader/reader_engine/shared/pagination_params.dart';

/// 分页引擎：封装 [PaginationSession] 创建/复用/释放。
///
/// ### 生命周期
/// 1. `createSession(bookId, chapterIndex, params, maxChars?)` — 创建新会话
/// 2. 通过 [session] 访问会话进行分页
/// 3. `disposeSession()` — 释放会话
///
/// ### 所有权
/// Engine 持有会话所有权。consumer（如 orchestrator）通过 [session] 引用，
/// 不管理会话生命周期。
class PaginationEngine {
  PaginationSession? _session;
  final ChapterContentRepository _contentRepo;

  PaginationEngine(this._contentRepo);

  /// 当前分页会话。
  PaginationSession? get session => _session;

  /// 当前分页描述子（便捷访问）。
  List<PackedPage>? get descriptors => _session?.descriptors;

  /// 创建分页会话（如果已有则自动释放）。
  PaginationSession createSession({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
  }) {
    disposeSession();
    _session = PaginationSession(
      onCacheUpdated: () => _contentRepo.preloadGeneration.value++,
    );
    return _session!;
  }

  /// 释放当前分页会话。
  void disposeSession() {
    _session?.dispose();
    _session = null;
  }
}
