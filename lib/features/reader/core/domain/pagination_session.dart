import 'package:zephyr_reader/features/reader/data/pagination_engine.dart';
import 'package:zephyr_reader/features/reader/data/pagination_params.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';

/// 单次章节分页会话抽象。
///
/// 持有 bookId、chapterIndex、filePath 等会话状态，
/// 以及描述符、页面缓存等分页结果。
abstract class PaginationSession {
  List<PageDescriptor>? get descriptors;

  List<PageInfo>? get approximatePages;

  set approximatePages(List<PageInfo>? pages);

  Future<({int totalPages, bool isPartial})> paginatePartial({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
  });

  Future<int> paginateFull({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
  });

  Future<({int totalPages, bool isPartial})> paginateQuickFirstScreen({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
  });

  String? pageContent(int pageIndex);

  void ensureWindow(int centerPage);

  void warmPageCache(int pageIndex, String content);

  void dispose();
}
