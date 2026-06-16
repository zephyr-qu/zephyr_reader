import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_view_model.dart';
import 'package:zephyr_reader/features/reader/domain/model/page_info.dart';
import 'package:zephyr_reader/features/reader/data/pagination_params.dart';
import 'package:zephyr_reader/features/reader/data/typeset_calibrator.dart';
import 'package:zephyr_reader/features/reader/data/pagination_engine.dart';
import 'package:zephyr_reader/features/reader/core/domain/reader_repository_interface.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 分页排版协调器：构建参数、局部分页、全量分页及 Dart 回退。
class PaginationCoordinator {
  final ReaderRepositoryInterface _repo;
  final ReaderConfig _config;
  final ChapterViewModel _chapterVM;

  PaginationCoordinator(this._repo, this._config, this._chapterVM);

  /// 页面宽度（逻辑像素）
  double pageWidth = 400;

  /// 页面高度（逻辑像素）
  double pageHeight = 600;

  /// 设备像素比，用于 dp → px 转换
  double devicePixelRatio = 1.0;

  /// 字符宽度校准数据
  Signal<CalibrationData?> calibration = signal<CalibrationData?>(null);

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
      calibration: calibration.value,
      fontFamily: fontFamily,
      letterSpacing: _config.letterSpacing.value,
      paragraphSpacing: _config.paragraphSpacing.value,
      punctuationSqueeze: _config.punctuationSqueeze.value,
      firstLineIndent: _config.firstLineIndent.value,
      enableHyphenation: _config.enableHyphenation.value,
      language: _config.language.value,
      autoSpaceRatio: _config.autoSpaceRatio.value,
    );
  }

  /// 首屏近似分页（毫秒级）。
  List<PageInfo> paginateApproximate(String firstText) {
    return _repo.paginateApproximate(
      firstText,
      fontSize: _config.fontSize.value,
      lineHeight: _config.lineHeight.value,
      width: pageWidth,
      height: pageHeight,
      padding: _config.padding.value,
    );
  }

  /// 首屏分页（统一入口，maxChars=2000）。
  Future<({int totalPages, bool isPartial})> paginateFirstScreen(
    int chapterIndex,
  ) {
    return _repo.beginPaginate(
      bookId: _chapterVM.bookId.value,
      chapterIndex: chapterIndex,
      params: buildPaginationParams(),
      maxChars: PaginationEngine.firstScreenMaxChars,
    );
  }

  /// 全量 Rust 分页（升级现有会话）。
  Future<int> expandToFullChapter(int chapterIndex) async {
    final r = await _repo.expandToFullChapter(
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
    return _repo.repaginateInPlace(
      bookId: _chapterVM.bookId.value,
      chapterIndex: _chapterVM.chapterIndex.value,
      params: buildPaginationParams(),
      maxChars: maxChars ?? PaginationEngine.firstScreenMaxChars,
    );
  }

  /// Rust 分页失败时回退到 Dart 估算分页。
  Future<({int totalPages, int pageIndex})> fallbackToCalculatePages({
    required int chapterIndex,
    required int initialCharOffset,
    required String content,
  }) async {
    Logging.warning(
      'loadChapter: Rust pagination fallback, using Dart approximate',
    );
    _repo.disposePagination();
    final pages = await _repo.calculatePages(
      bookId: _chapterVM.bookId.value,
      chapterId: chapterIndex,
      fontSize: _config.fontSize.value,
      lineHeight: _config.lineHeight.value,
      width: pageWidth,
      height: pageHeight,
      padding: _config.padding.value,
    );

    final charOffset = initialCharOffset.clamp(0, content.length);
    final resolvedPage = PaginationEngine.resolvePageIndexFromPageInfo(
      pages,
      charOffset,
    );
    _repo.ensurePageWindow(resolvedPage);

    Logging.debug(
      'loadChapter (fallback): pages=${pages.length} '
      'resolvePage=$resolvedPage off=$charOffset',
    );

    return (totalPages: pages.length, pageIndex: resolvedPage);
  }

  /// 应用完整 Rust 分页结果。
  ({int totalPages, int pageIndex}) applyFullResult({
    required int total,
    required int initialCharOffset,
    required String content,
  }) {
    final charOffset = initialCharOffset.clamp(0, content.length);
    final descriptors = _repo.descriptors!;
    final resolvedPage = PaginationEngine.resolvePageIndexForOffset(
      descriptors,
      charOffset,
    );
    _repo.ensurePageWindow(resolvedPage);

    Logging.debug(
      'loadChapter: pages=${descriptors.length} '
      'resolvePage=$resolvedPage off=$charOffset',
    );

    return (totalPages: total, pageIndex: resolvedPage);
  }

  /// 释放 Rust 会话并清空本地缓存。
  void disposePagination() => _repo.disposePagination();

  /// 判断 Rust 分页是否有效。
  bool isPaginationValid(int total) {
    final descriptors = _repo.descriptors;
    return total > 0 && descriptors != null && descriptors.isNotEmpty;
  }
}
