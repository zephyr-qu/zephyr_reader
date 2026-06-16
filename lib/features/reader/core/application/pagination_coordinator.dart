import 'package:zephyr_reader/core/reader/reader_config.dart';
import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/reader/core/application/reader_page_state.dart';
import 'package:zephyr_reader/features/reader/data/pagination_engine.dart';
import 'package:zephyr_reader/features/reader/data/pagination_params.dart';
import 'package:zephyr_reader/features/reader/data/typeset_calibrator.dart';
import 'package:zephyr_reader/features/reader/core/domain/reader_repository_interface.dart';
import 'package:signals_flutter/signals_flutter.dart';

/// 分页排版协调器：构建参数、局部分页、全量分页及 Dart 回退。
class PaginationCoordinator {
  final ReaderRepositoryInterface _repo;
  final ReaderConfig _config;
  final ReaderPageState _pageState;

  PaginationCoordinator(this._repo, this._config, this._pageState);

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

  /// 快速局部分页（50K 字符上限）。
  Future<({int totalPages, bool isPartial})> paginatePartial(
    int chapterIndex,
  ) {
    return _repo.paginateChapterPartial(
      bookId: _pageState.bookId.value,
      chapterIndex: chapterIndex,
      params: buildPaginationParams(),
    );
  }

  /// Rust 首屏快速分页（2000 字符上限），复用同一 session。
  Future<({int totalPages, bool isPartial})> paginateQuickFirstScreen(
    int chapterIndex,
  ) {
    return _repo.paginateChapterQuickFirstScreen(
      bookId: _pageState.bookId.value,
      chapterIndex: chapterIndex,
      params: buildPaginationParams(),
    );
  }

  /// 全量 Rust 分页。
  Future<int> paginateFull(int chapterIndex) {
    return _repo.paginateChapter(
      bookId: _pageState.bookId.value,
      chapterIndex: chapterIndex,
      params: buildPaginationParams(),
    );
  }

  /// 应用局部分页结果到 totalPages / pageIndex。
  void applyPartialResult({
    required int partialTotal,
    required int charOffset,
    required Signal<int> totalPages,
    required Signal<int> pageIndex,
  }) {
    if (partialTotal <= 0) return;
    final partialDesc = _repo.descriptors;
    if (partialDesc == null || partialDesc.isEmpty) return;
    totalPages.value = partialTotal;
    pageIndex.value = PaginationEngine.resolvePageIndexForOffset(
      partialDesc,
      charOffset,
    );
    _repo.ensurePageWindow(pageIndex.value);
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
    final pages = await _repo.calculatePages(
      bookId: _pageState.bookId.value,
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

  /// 判断 Rust 分页是否有效。
  bool isPaginationValid(int total) {
    final descriptors = _repo.descriptors;
    return total > 0 && descriptors != null && descriptors.isNotEmpty;
  }
}
