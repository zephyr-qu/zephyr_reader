import 'package:zephyr_reader/features/reader/domain/config/reader_config.dart';

/// pagination 模式的翻页动画皮肤（ADR-002：非独立 ReadingMode）。
enum PaginationSkin {
  /// 左右滑动（PageView）
  slide,

  /// 仿真卷曲（PageCurlWidget / PageTurnShell）
  curl,
}

/// 分页链路：仅 [ReadingMode.pagination]。
bool needsPagination(ReadingMode mode) => mode == ReadingMode.pagination;

/// 是否使用卷曲皮肤（pagination + curl）。
bool usesPageCurlSkin({
  required ReadingMode mode,
  required PaginationSkin skin,
}) => mode == ReadingMode.pagination && skin == PaginationSkin.curl;
