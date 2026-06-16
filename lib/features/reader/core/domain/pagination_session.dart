import 'package:zephyr_reader/features/reader/data/pagination_params.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';

/// 单次章节分页会话抽象。
///
/// 持有 bookId、chapterIndex、filePath 等会话状态，
/// 以及描述符、页面缓存等分页结果。
abstract class PaginationSession {
  List<PageDescriptor>? get descriptors;

  /// 创建分页会话并分页。maxChars=null 表示全章。
  Future<({int totalPages, bool isPartial})> beginPaginate({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
    BigInt? maxChars,
  });

  /// 在同一会话上扩展到全章。
  Future<({int totalPages, bool isPartial})> expandToFullChapter({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
  });

  String? pageContent(int pageIndex);

  void ensureWindow(int centerPage);

  void warmPageCache(int pageIndex, String content);

  void dispose();
}
