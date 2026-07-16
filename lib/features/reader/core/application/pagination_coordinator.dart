import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_view_model.dart';
import 'package:zephyr_reader/features/reader/domain/chapter_content_repository.dart';
import 'package:zephyr_reader/reader_engine/pagination/flutter_pagination_session.dart';
import 'package:zephyr_reader/features/reader/data/pagination_engine.dart';
import 'package:zephyr_reader/reader_engine/shared/pagination_params.dart';
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/reader_engine/pagination/packed_page.dart';

class PaginationCoordinator {
  final ChapterContentRepository _contentRepo;
  final PaginationSession _session;
  final ReaderConfig _config;
  final ChapterViewModel _chapterVM;

  PaginationCoordinator(
    this._contentRepo,
    this._session,
    this._config,
    this._chapterVM,
  );

  /// 页面宽度（逻辑像素）
  double pageWidth = 400;

  /// 页面高度（逻辑像素）
  double pageHeight = 600;

  /// 设备像素比，用于 dp → px 转换
  double devicePixelRatio = 1.0;

  /// 当前字体系列名
  String fontFamily = 'Noto Sans SC';

  PaginationParams buildPaginationParams() {
    return PaginationParams(
      fontSize: _config.fontSize.value,
      lineHeight: _config.lineHeight.value,
      width: pageWidth,
      height: pageHeight,
      padding: _config.padding.value,
      devicePixelRatio: devicePixelRatio,
      fontFamily: fontFamily,
      letterSpacing: _config.letterSpacing.value,
      paragraphSpacing: _config.paragraphSpacing.value,
      punctuationSqueeze: _config.punctuationSqueeze.value,
      firstLineIndent: _config.firstLineIndent.value,
      language: _config.language.value,
      autoSpaceRatio: _config.autoSpaceRatio.value,
    );
  }

  /// 将当前排版参数推送到章节内容仓库（滚动 EPUB 富文本 / staging 共用）。
  void syncChapterTypesetLayoutToRepo() {
    final params = buildPaginationParams();
    Logging.info(
      '[Typeset] syncLayout fontSize=${params.fontSize} lineHeight=${params.lineHeight}'
      ' width=${params.width} height=${params.height}'
      ' font=${params.fontFamily}',
    );
    _contentRepo.syncChapterTypesetLayout(params);
  }

  /// 计算当前排版配置的哈希值，用于检测配置变更。
  /// Dart 侧直接计算（分页已迁 Flutter）。
  BigInt computeConfigHash() {
    final p = buildPaginationParams();
    return BigInt.from(
      Object.hash(
        p.width,
        p.height,
        p.fontSize,
        p.lineHeight,
        p.padding,
        p.devicePixelRatio,
        p.fontFamily,
        p.letterSpacing,
        p.paragraphSpacing,
        p.punctuationSqueeze,
        p.firstLineIndent,
        p.language,
        p.autoSpaceRatio,
      ),
    );
  }

  /// 首屏分页（统一入口，maxChars=2000）。
  Future<({int totalPages, bool isPartial})> paginateFirstScreen(
    int chapterIndex,
  ) {
    Logging.info(
      '[FirstLoad] paginateFirstScreen chapter=$chapterIndex'
      ' maxChars=${PaginationEngine.firstScreenMaxChars}',
    );
    return _session.beginPaginate(
      bookId: _chapterVM.bookId.value,
      chapterIndex: chapterIndex,
      params: buildPaginationParams(),
      maxChars: PaginationEngine.firstScreenMaxChars,
    );
  }

  /// 全章分页（字号变更后重装箱；maxChars=null）。
  Future<({int totalPages, bool isPartial})> paginateFullChapter(
    int chapterIndex,
  ) {
    return _session.beginPaginate(
      bookId: _chapterVM.bookId.value,
      chapterIndex: chapterIndex,
      params: buildPaginationParams(),
      maxChars: null,
    );
  }

  /// 首屏分页（优先 adopt cache，miss 时 fallback create）。
  Future<({int totalPages, bool isPartial})> paginateFirstScreenFromCache(
    int chapterIndex,
  ) {
    return _session.beginPaginateFromCache(
      bookId: _chapterVM.bookId.value,
      chapterIndex: chapterIndex,
      params: buildPaginationParams(),
      maxChars: PaginationEngine.firstScreenMaxChars,
    );
  }

  /// 全量 Flutter 分页（升级现有会话）。
  Future<int> expandToFullChapter(int chapterIndex) async {
    final r = await _session.expandToFullChapter(
      bookId: _chapterVM.bookId.value,
      chapterIndex: chapterIndex,
      params: buildPaginationParams(),
    );
    return r.totalPages;
  }

  /// 设置重载专用：in-place repaginate 同 handle。
  /// maxChars 留空表示首屏 2000 字符。
  Future<({int totalPages, bool isPartial})> repaginateCurrentChapter({
    BigInt? maxChars,
  }) {
    return _session.repaginateInPlace(
      bookId: _chapterVM.bookId.value,
      chapterIndex: _chapterVM.chapterIndex.value,
      params: buildPaginationParams(),
      maxChars: maxChars ?? PaginationEngine.firstScreenMaxChars,
    );
  }

  /// 应用完整分页结果。
  ({int totalPages, int pageIndex}) applyFullResult({
    required int total,
    required int initialCharOffset,
    required String content,
  }) {
    final descriptors = _session.descriptors!;
    final maxOffset = PaginationEngine.chapterCharOffsetMax(
      descriptors: descriptors,
      phase1PlainContent: content,
    );
    final charOffset = initialCharOffset.clamp(0, maxOffset);
    final resolvedPage = resolvePageForCharOffset(charOffset, descriptors);
    _session.ensureWindow(resolvedPage);

    Logging.debug(
      'loadChapter: pages=${descriptors.length} '
      'resolvePage=$resolvedPage off=$charOffset',
    );

    return (totalPages: total, pageIndex: resolvedPage);
  }

  /// charOffset → pageIndex：优先 session，回退 descriptor 二分。
  int resolvePageForCharOffset(int charOffset, List<PackedPage> descriptors) {
    final sessionPage = _session.resolvePageIndexForCharOffset(charOffset);
    if (sessionPage != null) {
      return sessionPage.clamp(0, descriptors.length - 1);
    }
    return PaginationEngine.resolvePageIndexForOffset(descriptors, charOffset);
  }

  /// 释放分页会话并清空本地缓存。
  void disposePagination() => _session.dispose();

  /// 判断分页是否有效。
  bool isPaginationValid(int total) {
    final descriptors = _session.descriptors;
    return total > 0 && descriptors != null && descriptors.isNotEmpty;
  }
}
