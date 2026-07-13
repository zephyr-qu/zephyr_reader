import 'package:zephyr_reader/features/reader/data/pagination_params.dart';
import 'package:zephyr_reader/features/reader/flutter_pagination/packed_page.dart';
import 'package:zephyr_reader/src/rust/domain/types/block_pagination.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';

/// 单次章节分页会话抽象。
///
/// 持有 bookId、chapterIndex、filePath 等会话状态，
/// 以及描述符、页面缓存等分页结果。
abstract class PaginationSession {
  List<PackedPage>? get descriptors;

  /// 上次分页的 configHash；null 表示无 session。
  BigInt? get sessionConfigHash;

  /// 当前分页会话对应的章节索引；null 表示无 session。
  int? get sessionChapterIndex;

  /// 当前分页结果是否为部分分页。
  bool get sessionIsPartial;

  /// 分页引擎模式（plain / content blocks）。
  ChapterPaginationMode get sessionMode;

  /// 分页 session 绑定的书籍文件路径（块模式图片 decode 用）。
  String? get sessionFilePath;

  /// 页内块列表（`contentBlocks` 模式）；未缓存时返回 null。
  List<PageBlockSlice>? pageBlocks(int pageIndex);

  /// In-place repaginate：复用现有 session handle，更新 config。
  /// handle 不存在时退化到 [beginPaginate]（用真实 bookId/chapterIndex）。
  Future<({int totalPages, bool isPartial})> repaginateInPlace({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
    BigInt? maxChars,
  });

  /// 异步拉取并缓存单页 plain text（metrics 回传用）。
  Future<String?> fetchPageContent(int pageIndex);

  /// 创建分页会话并分页。maxChars=null 表示全章。
  Future<({int totalPages, bool isPartial})> beginPaginate({
    required String bookId,
    required int chapterIndex,
    required PaginationParams params,
    BigInt? maxChars,
  });

  /// 尝试从 Rust STREAMER_CACHE adopt 现有 session（零重 paginate）。
  /// 未命中时退化到 [beginPaginate]（full createPaginationSession）。
  Future<({int totalPages, bool isPartial})> beginPaginateFromCache({
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

  /// 章级 charOffset → pageIndex（session 可用时走 Rust 精确解析）。
  int? resolvePageIndexForCharOffset(int charOffset);

  void dispose();
}
