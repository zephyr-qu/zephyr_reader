import 'package:zephyr_reader/core/reader_engine/shared/ir_types.dart';

/// 当前 FlutterPaginationSession 持有的章 IR（供渲染查 Image intrinsic，避免改 FRB）。
abstract final class ActiveChapterIr {
  static ReaderChapterIr? current;

  static void set(ReaderChapterIr? ir) => current = ir;

  static void clear() => current = null;

  /// 按 assetId 查 IR 中的图块（无则 null）。
  static ReaderIrBlock? findImage(String assetId) {
    final ir = current;
    if (ir == null || assetId.isEmpty) return null;
    for (final b in ir.blocks) {
      if (b.kind == ReaderIrBlockKind.image && b.imageAssetId == assetId) return b;
    }
    return null;
  }
}
