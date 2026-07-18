import 'package:zephyr_reader/core/reader_engine/data/chapter_content_repository.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/flutter_pagination_session.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/packed_page.dart';
import 'package:zephyr_reader/core/reader_engine/pagination/page_plan.dart';

/// 分页引擎：PaginationSession 唯一所有者。
///
/// 生命周期：
/// 1. 构造时自动创建会话
/// 2. consumer 通过 [session] 或便捷 getter 访问
/// 3. [disposeSession] 释放（switch 到非分页模式/换书时调用）
/// 4. [recreateSession] 重建（需要新 session handle 时触发）
///
/// ### 所有权
/// Engine 持有会话所有权。consumer 通过 [session] 引用，
/// 不管理会话生命周期。
class PaginationEngine {
  PaginationSession _session;
  final ChapterContentRepository _contentRepo;

  PaginationEngine(this._contentRepo)
      : _session = PaginationSession(
            onCacheUpdated: () => _contentRepo.preloadGeneration.value++,
          );

  /// 当前分页会话。
  PaginationSession get session => _session;

  /// 当前页描述子。
  /// 当前页描述子（PackedPage——旧版，计划删除）。
  List<PackedPage>? get descriptors => _session.descriptors;

  /// 当前页模型列表（PagePlan——新版）。
  List<PagePlan>? get pagePlans => _session.pagePlans;

  /// EPUB 文件路径（图片渲染用）。
  String? get sessionFilePath => _session.sessionFilePath;

  /// 确保页窗口缓存（page block 预加载）。
  void ensureWindow(int pageIndex) => _session.ensureWindow(pageIndex);

  /// 重建分页会话（先释放旧会话）。
  PaginationSession recreateSession() {
    disposeSession();
    _session = PaginationSession(
      onCacheUpdated: () => _contentRepo.preloadGeneration.value++,
    );
    return _session;
  }

  /// 释放当前分页会话。
  void disposeSession() {
    _session.dispose();
    _session = PaginationSession(
      onCacheUpdated: () => _contentRepo.preloadGeneration.value++,
    );
  }
}
