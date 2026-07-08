import 'package:flutter/painting.dart' show TextStyle;
import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';
import 'package:zephyr_reader/features/reader/data/line_break_extractor.dart';
import 'package:zephyr_reader/src/rust/api/core.dart' as core_api;

import 'package:zephyr_reader/core/utils/logging.dart';
import 'package:zephyr_reader/features/reader/core/application/chapter_view_model.dart';
import 'package:zephyr_reader/features/reader/data/pagination_params.dart';
import 'package:zephyr_reader/features/reader/data/typeset_calibrator.dart';
import 'package:zephyr_reader/features/reader/data/pagination_engine.dart';
import 'package:zephyr_reader/features/reader/core/domain/reader_repository_interface.dart';
import 'package:zephyr_reader/src/rust/domain/types/pagination.dart';
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
    _repo.syncChapterTypesetLayout(params);
  }

  /// 计算当前排版配置的哈希值，用于检测配置变更。
  /// 与 Rust 侧 `TypesetConfig::config_hash()` 算法一致。
  /// 返回 BigInt（Rust u64 → Dart BigInt），不做截断。
  BigInt computeConfigHash() {
    final p = buildPaginationParams();
    final layoutInsets = paginatedTypesetLayoutInsets(
      fontSize: p.fontSize,
      lineHeight: p.lineHeight,
      paragraphSpacing: p.paragraphSpacing,
    );
    return core_api.computeConfigHash(
      config: buildTypesetConfig(
        width: p.width,
        height: p.height,
        fontSize: p.fontSize,
        lineHeight: p.lineHeight,
        padding: p.padding,
        contentVerticalPadding: layoutInsets.contentVerticalPadding,
        pageHeightLineBuffer: layoutInsets.pageHeightLineBuffer,
        devicePixelRatio: p.devicePixelRatio,
        calibration: p.calibration,
        fontFamily: p.fontFamily,
        letterSpacing: p.letterSpacing,
        paragraphSpacing: p.paragraphSpacing,
        punctuationSqueeze: p.punctuationSqueeze,
        firstLineIndent: p.firstLineIndent ? 2 : 0,
        language: p.language,
        autoSpaceRatio: p.autoSpaceRatio,
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
    return _repo.beginPaginate(
      bookId: _chapterVM.bookId.value,
      chapterIndex: chapterIndex,
      params: buildPaginationParams(),
      maxChars: PaginationEngine.firstScreenMaxChars,
    );
  }

  /// 首屏分页（优先 adopt cache，miss 时 fallback create）。
  Future<({int totalPages, bool isPartial})> paginateFirstScreenFromCache(
    int chapterIndex,
  ) {
    return _repo.beginPaginateFromCache(
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

  /// P4-4：首屏 metrics 回传后 repaginate（仅更新 calibration）。
  Future<({int totalPages, bool isPartial})> repaginateAfterMetricsBackfeed({
    BigInt? maxChars,
  }) {
    return _repo.applySessionCalibration(
      bookId: _chapterVM.bookId.value,
      chapterIndex: _chapterVM.chapterIndex.value,
      params: buildPaginationParams(),
      maxChars: maxChars,
    );
  }

  /// 应用完整 Rust 分页结果。
  ({int totalPages, int pageIndex}) applyFullResult({
    required int total,
    required int initialCharOffset,
    required String content,
  }) {
    final descriptors = _repo.descriptors!;
    final maxOffset = PaginationEngine.chapterCharOffsetMax(
      sessionMode: _repo.sessionMode,
      descriptors: descriptors,
      phase1PlainContent: content,
    );
    final charOffset = initialCharOffset.clamp(0, maxOffset);
    final resolvedPage = resolvePageForCharOffset(charOffset, descriptors);
    _repo.ensurePageWindow(resolvedPage);

    Logging.debug(
      'loadChapter: pages=${descriptors.length} '
      'resolvePage=$resolvedPage off=$charOffset',
    );

    return (totalPages: total, pageIndex: resolvedPage);
  }

  /// charOffset → pageIndex：优先 Rust session，回退 descriptor 二分。
  int resolvePageForCharOffset(
    int charOffset,
    List<PageDescriptor> descriptors,
  ) {
    final sessionPage = _repo.resolvePageIndexForCharOffset(charOffset);
    if (sessionPage != null) {
      return sessionPage.clamp(0, descriptors.length - 1);
    }
    return PaginationEngine.resolvePageIndexForOffset(descriptors, charOffset);
  }

  /// 释放 Rust 会话并清空本地缓存。
  void disposePagination() => _repo.disposePagination();

  /// 判断 Rust 分页是否有效。
  bool isPaginationValid(int total) {
    final descriptors = _repo.descriptors;
    return total > 0 && descriptors != null && descriptors.isNotEmpty;
  }

  /// Phase 6: 提取当前章节的行断点索引并存入 Rust 缓存。
  ///
  /// 在全章分页完成后调用（finalize 后）。下次同 config_hash 分页时
  /// Rust `paginate_from_line_breaks` 直接使用这些索引做纯数学映射。
  Future<void> storeLineBreaks(String content) async {
    if (content.isEmpty) return;
    final configHash = computeConfigHash();
    final params = buildPaginationParams();

    try {
      final indices = computeLineBreakIndices(
        text: content,
        style: TextStyle(
          fontSize: params.fontSize,
          height: params.lineHeight,
          fontFamily: params.fontFamily,
        ),
        maxWidth: params.width - 2 * params.padding,
      );

      if (indices.isEmpty) return;

      core_api.storeLineBreaks(
        bookId: _chapterVM.bookId.value,
        chapterIndex: _chapterVM.chapterIndex.value,
        configHash: configHash,
        lineBreaks: indices,
      );
      Logging.info(
        '[LineBreaks] stored ${indices.length} indices '
        'ch=${_chapterVM.chapterIndex.value} hash=${configHash.toString().padLeft(16, '0')}',
      );
    } catch (e, st) {
      Logging.warning('[LineBreaks] extraction failed: $e\n$st');
    }
  }
}
